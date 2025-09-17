import Foundation
import AVFoundation // Still needed for AVAudioSession category/mode
import SwiftUI

// CRITICAL: DO NOT revert to deprecated AVAudioSession.RecordPermission enum cases
// These cause build errors in iOS 17.0+. Use AVAudioApplication.RecordPermission instead.
@MainActor
class MicrophonePermissionManager: ObservableObject {
    static let shared = MicrophonePermissionManager()
    
    @Published var permissionStatus: AVAudioSession.RecordPermission = {
        if #available(iOS 17.0, *) {
            let appPermission = AVAudioApplication.shared.recordPermission
            switch appPermission {
            case .undetermined: return AVAudioSession.RecordPermission.undetermined
            case .denied: return AVAudioSession.RecordPermission.denied
            case .granted: return AVAudioSession.RecordPermission.granted
            @unknown default: return AVAudioSession.RecordPermission.undetermined
            }
        } else {
            return AVAudioSession.sharedInstance().recordPermission
        }
    }()
    @Published var showPermissionAlert = false
    @Published var permissionDeniedAlert = false
    
    private init() {
        updatePermissionStatus()
    }
    
    func updatePermissionStatus() {
        if #available(iOS 17.0, *) {
            let appPermission = AVAudioApplication.shared.recordPermission
            switch appPermission {
            case .undetermined:
                permissionStatus = AVAudioSession.RecordPermission.undetermined
            case .denied:
                permissionStatus = AVAudioSession.RecordPermission.denied
            case .granted:
                permissionStatus = AVAudioSession.RecordPermission.granted
            @unknown default:
                permissionStatus = AVAudioSession.RecordPermission.undetermined
            }
        } else {
            permissionStatus = AVAudioSession.sharedInstance().recordPermission
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { allowed in
                    Task { @MainActor in
                        self.permissionStatus = allowed ? AVAudioSession.RecordPermission.granted : AVAudioSession.RecordPermission.denied
                        if !allowed {
                            self.permissionDeniedAlert = true
                        }
                        continuation.resume(returning: allowed)
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    Task { @MainActor in
                        self.permissionStatus = allowed ? AVAudioSession.RecordPermission.granted : AVAudioSession.RecordPermission.denied
                        if !allowed {
                            self.permissionDeniedAlert = true
                        }
                        continuation.resume(returning: allowed)
                    }
                }
            }
        }
    }
    
    func checkAndRequestPermissionIfNeeded() {
        updatePermissionStatus()
        
        switch permissionStatus {
        case .undetermined:
            Task {
                await requestMicrophonePermission()
            }
        case .denied:
            permissionDeniedAlert = true
        case .granted:
            break
        @unknown default:
            break
        }
    }
    
    var hasPermission: Bool {
        return permissionStatus == AVAudioSession.RecordPermission.granted
    }
    
    var needsPermission: Bool {
        return permissionStatus != AVAudioSession.RecordPermission.granted
    }
    
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            Task { @MainActor in
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
}

struct MicrophonePermissionView: View {
    @StateObject private var permissionManager = MicrophonePermissionManager.shared
    let onPermissionGranted: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.fill")
                .font(.system(size: 64))
                .foregroundColor(ColorTheme.primaryAccent)
            
            VStack(spacing: 12) {
                Text("Microphone Access Required")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("This app needs microphone access to record your voice for interviews and voice logs. Your recordings stay private and secure.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button("Allow Microphone Access") {
                    permissionManager.checkAndRequestPermissionIfNeeded()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                if permissionManager.needsPermission && permissionManager.permissionStatus != AVAudioSession.RecordPermission.undetermined {
                    Button("Open Settings") {
                        permissionManager.openSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .onChange(of: permissionManager.permissionStatus) { newStatus in
            if permissionManager.hasPermission {
                onPermissionGranted()
            }
        }
        .onAppear {
            permissionManager.updatePermissionStatus()
        }
        .alert("Microphone Access Denied", isPresented: $permissionManager.permissionDeniedAlert) {
            Button("Settings") {
                permissionManager.openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable microphone access in Settings to use voice features.")
        }
    }
}