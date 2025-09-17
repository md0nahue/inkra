import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var currentInput: AVAudioSessionPortDescription?
    @Published var currentOutput: AVAudioSessionPortDescription?
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var availableOutputs: [AVAudioSessionPortDescription] = []
    @Published var showDeviceToast = false
    @Published var lastConnectedDevice: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let audioSession = AVAudioSession.sharedInstance()
    
    private init() {
        setupNotifications()
        updateCurrentDevices()
    }
    
    private func setupNotifications() {
        // Monitor route changes
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)
        
        // Monitor available inputs changes
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAvailableInputs()
            }
            .store(in: &cancellables)
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🎧 Audio route change detected: \(reason)")
        
        switch reason {
        case .newDeviceAvailable:
            updateCurrentDevices()
            showNewDeviceToast()
        case .oldDeviceUnavailable:
            updateCurrentDevices()
            // Automatically switch to best available device
            selectBestAvailableDevices()
        case .categoryChange, .override:
            updateCurrentDevices()
        default:
            updateCurrentDevices()
        }
    }
    
    private func updateCurrentDevices() {
        let currentRoute = audioSession.currentRoute
        
        // Update current input
        currentInput = currentRoute.inputs.first
        
        // Update current output
        currentOutput = currentRoute.outputs.first
        
        // Update available devices
        updateAvailableInputs()
        updateAvailableOutputs()
        
        print("📱 Current devices updated:")
        print("   Input: \(currentInput?.portName ?? "None")")
        print("   Output: \(currentOutput?.portName ?? "None")")
    }
    
    private func updateAvailableInputs() {
        availableInputs = audioSession.availableInputs ?? []
        print("🎤 Available inputs: \(availableInputs.map { $0.portName })")
    }
    
    private func updateAvailableOutputs() {
        // Get all available output routes
        let currentRoute = audioSession.currentRoute
        availableOutputs = currentRoute.outputs
        
        // Try to get additional output options from available categories
        if audioSession.category == .playAndRecord {
            // When in playAndRecord mode, we can switch between speaker and other outputs
            let outputs: [AVAudioSessionPortDescription] = currentRoute.outputs
            
            // Check if we can add speaker option
            if !outputs.contains(where: { $0.portType == .builtInSpeaker }) {
                // Note: We can't create port descriptions directly, but we can track the option
                // The actual switching will be done through overrideOutputAudioPort
            }
            
            availableOutputs = outputs
        }
        
        print("🔊 Available outputs: \(availableOutputs.map { $0.portName })")
    }
    
    private func showNewDeviceToast() {
        // Determine what was connected
        let currentRoute = audioSession.currentRoute
        
        // Check for new headphones/earbuds
        if let output = currentRoute.outputs.first {
            if output.portType == .headphones || 
               output.portType == .bluetoothA2DP ||
               output.portType == .bluetoothLE ||
               output.portType == .airPlay {
                lastConnectedDevice = output.portName
                showDeviceToast = true
                
                // Auto-dismiss toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.showDeviceToast = false
                }
            }
        }
        
        // Check for new microphone
        if let input = currentRoute.inputs.first {
            if input.portType == .bluetoothHFP ||
               input.portType == .usbAudio ||
               input.portType == .headsetMic {
                if lastConnectedDevice.isEmpty {
                    lastConnectedDevice = input.portName
                }
                showDeviceToast = true
                
                // Auto-dismiss toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.showDeviceToast = false
                }
            }
        }
    }
    
    private func selectBestAvailableDevices() {
        // Priority order for inputs
        let inputPriority: [AVAudioSession.Port] = [
            .headsetMic,
            .bluetoothHFP,
            .usbAudio,
            .builtInMic
        ]
        
        // Try to select best available input
        if let inputs = audioSession.availableInputs {
            for priority in inputPriority {
                if let preferredInput = inputs.first(where: { $0.portType == priority }) {
                    try? audioSession.setPreferredInput(preferredInput)
                    print("✅ Auto-selected input: \(preferredInput.portName)")
                    break
                }
            }
        }
        
        // For output, if headphones were disconnected, default to speaker
        let currentRoute = audioSession.currentRoute
        if !currentRoute.outputs.contains(where: { 
            $0.portType == .headphones || 
            $0.portType == .bluetoothA2DP 
        }) {
            try? audioSession.overrideOutputAudioPort(.speaker)
            print("✅ Auto-selected output: Speaker")
        }
    }
    
    // Public methods for manual device selection
    func selectInput(_ input: AVAudioSessionPortDescription) {
        do {
            try audioSession.setPreferredInput(input)
            currentInput = input
            print("✅ Selected input: \(input.portName)")
        } catch {
            print("❌ Failed to select input: \(error)")
        }
    }
    
    func selectOutput(useSpeaker: Bool) {
        do {
            if useSpeaker {
                try audioSession.overrideOutputAudioPort(.speaker)
                print("✅ Selected output: Speaker")
            } else {
                try audioSession.overrideOutputAudioPort(.none)
                print("✅ Selected output: Default (headphones/receiver)")
            }
            updateCurrentDevices()
        } catch {
            print("❌ Failed to select output: \(error)")
        }
    }
    
    func dismissToast() {
        showDeviceToast = false
    }
}