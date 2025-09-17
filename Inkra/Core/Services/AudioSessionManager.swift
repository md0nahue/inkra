import Foundation
import AVFoundation
import UIKit

@MainActor
class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()

    // MARK: - Published Properties
    @Published var isActive = false
    @Published var currentCategory: AVAudioSession.Category = .ambient
    @Published var currentMode: AVAudioSession.Mode = .default
    @Published var currentOptions: AVAudioSession.CategoryOptions = []
    @Published var isInterrupted = false
    @Published var interruptionReason: AVAudioSession.InterruptionReason?

    // MARK: - Configuration
    private let audioSession = AVAudioSession.sharedInstance()

    // MARK: - Callbacks
    var onInterruptionBegan: ((AVAudioSession.InterruptionReason?) -> Void)?
    var onInterruptionEnded: ((AVAudioSession.InterruptionOptions?) -> Void)?
    var onRouteChange: ((AVAudioSession.RouteChangeReason) -> Void)?
    var onMediaServicesReset: (() -> Void)?

    private init() {
        setupNotificationObservers()
        updateCurrentState()
    }

    // MARK: - Setup Methods

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSilenceSecondaryAudio),
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: audioSession
        )

        // App lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private func updateCurrentState() {
        currentCategory = audioSession.category
        currentMode = audioSession.mode
        currentOptions = audioSession.categoryOptions
        isActive = audioSession.isOtherAudioPlaying
    }

    // MARK: - Public Configuration Methods

    func configureForSpeechRecognition() throws {
        print("🎙️ Configuring audio session for speech recognition")

        try audioSession.setCategory(
            .record,
            mode: .measurement,
            options: [.duckOthers, .defaultToSpeaker]
        )

        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        updateCurrentState()
    }

    func configureForSpeechSynthesis() throws {
        print("🗣️ Configuring audio session for speech synthesis")

        try audioSession.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers]
        )

        try audioSession.setActive(true)
        updateCurrentState()
    }

    func configureForRecordingAndPlayback() throws {
        print("🎙️🗣️ Configuring audio session for recording and playback")

        try audioSession.setCategory(
            .playAndRecord,
            mode: .videoRecording,
            options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .duckOthers]
        )

        try audioSession.setActive(true)
        updateCurrentState()
    }

    func configureForAudioPlayback() throws {
        print("🎵 Configuring audio session for audio playback")

        try audioSession.setCategory(
            .playback,
            mode: .default,
            options: [.allowBluetooth, .allowBluetoothA2DP]
        )

        try audioSession.setActive(true)
        updateCurrentState()
    }

    func configureForAmbientAudio() throws {
        print("🔇 Configuring audio session for ambient audio")

        try audioSession.setCategory(
            .ambient,
            mode: .default,
            options: []
        )

        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        updateCurrentState()
    }

    func deactivateSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isActive = false
            print("🔇 Audio session deactivated")
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
    }

    // MARK: - Interrupt Handling

    func resumeAfterInterruption() throws {
        guard isInterrupted else { return }

        print("▶️ Resuming audio session after interruption")
        try audioSession.setActive(true)
        isInterrupted = false
        interruptionReason = nil
    }

    // MARK: - Audio Route Information

    func getCurrentAudioRoute() -> AVAudioSessionRouteDescription {
        return audioSession.currentRoute
    }

    func getAvailableInputs() -> [AVAudioSessionPortDescription]? {
        return audioSession.availableInputs
    }

    func getPreferredInput() -> AVAudioSessionPortDescription? {
        return audioSession.preferredInput
    }

    func setPreferredInput(_ input: AVAudioSessionPortDescription?) throws {
        try audioSession.setPreferredInput(input)
        print("🎙️ Set preferred input: \(input?.portName ?? "none")")
    }

    func isBluetoothConnected() -> Bool {
        let route = getCurrentAudioRoute()
        let bluetoothTypes: [AVAudioSession.Port] = [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE]

        for output in route.outputs {
            if bluetoothTypes.contains(output.portType) {
                return true
            }
        }

        for input in route.inputs {
            if bluetoothTypes.contains(input.portType) {
                return true
            }
        }

        return false
    }

    func isHeadphonesConnected() -> Bool {
        let route = getCurrentAudioRoute()
        let headphoneTypes: [AVAudioSession.Port] = [.headphones, .bluetoothA2DP, .bluetoothHFP]

        return route.outputs.contains { headphoneTypes.contains($0.portType) }
    }

    // MARK: - Sample Rate and Buffer Configuration

    func setPreferredSampleRate(_ sampleRate: Double) throws {
        try audioSession.setPreferredSampleRate(sampleRate)
        print("🎵 Set preferred sample rate: \(sampleRate) Hz")
    }

    func setPreferredIOBufferDuration(_ duration: TimeInterval) throws {
        try audioSession.setPreferredIOBufferDuration(duration)
        print("⏱️ Set preferred IO buffer duration: \(duration) seconds")
    }

    func optimizeForLowLatency() throws {
        print("⚡ Optimizing audio session for low latency")
        try setPreferredSampleRate(44100.0)
        try setPreferredIOBufferDuration(0.005) // 5ms buffer
    }

    func optimizeForQuality() throws {
        print("💎 Optimizing audio session for quality")
        try setPreferredSampleRate(48000.0)
        try setPreferredIOBufferDuration(0.02) // 20ms buffer
    }

    // MARK: - Notification Handlers

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        print("🚨 Audio interruption: \(type == .began ? "began" : "ended")")

        Task { @MainActor in
            switch type {
            case .began:
                isInterrupted = true

                if let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt,
                   let reason = AVAudioSession.InterruptionReason(rawValue: reasonValue) {
                    interruptionReason = reason
                    print("🚨 Interruption reason: \(reason)")
                }

                onInterruptionBegan?(interruptionReason)

            case .ended:
                var shouldResume = false

                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    shouldResume = options.contains(.shouldResume)

                    onInterruptionEnded?(options)
                    print("🔄 Interruption ended, should resume: \(shouldResume)")
                }

                if shouldResume {
                    do {
                        try resumeAfterInterruption()
                    } catch {
                        print("❌ Failed to resume after interruption: \(error)")
                    }
                }

            @unknown default:
                break
            }
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("🔄 Audio route changed: \(reason)")

        Task { @MainActor in
            onRouteChange?(reason)

            switch reason {
            case .newDeviceAvailable:
                print("🎧 New audio device available")
            case .oldDeviceUnavailable:
                print("🔌 Audio device disconnected")
            case .categoryChange:
                print("📱 Audio category changed")
                updateCurrentState()
            default:
                break
            }
        }
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        print("🔄 Media services were reset")

        Task { @MainActor in
            // Re-establish audio session configuration
            do {
                try configureForRecordingAndPlayback()
                onMediaServicesReset?()
            } catch {
                print("❌ Failed to reconfigure audio session after reset: \(error)")
            }
        }
    }

    @objc private func handleSilenceSecondaryAudio(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let hintTypeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let hintType = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: hintTypeValue) else {
            return
        }

        print("🔇 Secondary audio hint: \(hintType == .begin ? "begin silence" : "end silence")")
    }

    @objc private func handleAppWillResignActive(_ notification: Notification) {
        print("📱 App will resign active - considering audio session deactivation")
        // Optionally deactivate session when app goes to background
        // This depends on your app's requirements
    }

    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        print("📱 App did become active - checking audio session state")
        updateCurrentState()
    }

    // MARK: - Debug Information

    func printDebugInfo() {
        print("\n🔍 Audio Session Debug Info:")
        print("   Category: \(currentCategory.rawValue)")
        print("   Mode: \(currentMode.rawValue)")
        print("   Options: \(currentOptions)")
        print("   Is Active: \(isActive)")
        print("   Is Interrupted: \(isInterrupted)")
        print("   Sample Rate: \(audioSession.sampleRate) Hz")
        print("   IO Buffer Duration: \(audioSession.ioBufferDuration) seconds")
        print("   Input Gain: \(audioSession.inputGain)")
        print("   Output Volume: \(audioSession.outputVolume)")
        print("   Bluetooth Connected: \(isBluetoothConnected())")
        print("   Headphones Connected: \(isHeadphonesConnected())")

        let route = getCurrentAudioRoute()
        print("   Current Route:")
        for input in route.inputs {
            print("     Input: \(input.portName) (\(input.portType.rawValue))")
        }
        for output in route.outputs {
            print("     Output: \(output.portName) (\(output.portType.rawValue))")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Error Types

enum AudioSessionError: LocalizedError {
    case configurationFailed(Error)
    case activationFailed(Error)
    case deactivationFailed(Error)
    case routeChangeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .configurationFailed(let error):
            return "Audio session configuration failed: \(error.localizedDescription)"
        case .activationFailed(let error):
            return "Audio session activation failed: \(error.localizedDescription)"
        case .deactivationFailed(let error):
            return "Audio session deactivation failed: \(error.localizedDescription)"
        case .routeChangeFailed(let error):
            return "Audio route change failed: \(error.localizedDescription)"
        }
    }
}