import SwiftUI
import AVFoundation

// CRITICAL: DO NOT revert deprecated API fixes in this file
// Using .undetermined directly causes build errors in iOS 17.0+
@available(iOS 15.0, *)
struct PermissionsCheckView: View {
    @StateObject private var microphoneManager = MicrophonePermissionManager.shared
    @StateObject private var notificationManager = NotificationPermissionManager.shared
    @State private var currentPermissionStep: PermissionStep = .microphone
    @State private var isCheckingPermissions = true
    
    let onComplete: () -> Void
    
    enum PermissionStep {
        case microphone
        case notification
        case complete
    }
    
    var body: some View {
        ZStack {
            ColorTheme.primaryBackground.ignoresSafeArea()
            
            if isCheckingPermissions {
                // Initial checking state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Checking permissions...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                // Permission request flow
                Group {
                    switch currentPermissionStep {
                    case .microphone:
                        MicrophonePermissionRequestView {
                            moveToNextStep()
                        }
                    case .notification:
                        NotificationPermissionRequestView {
                            moveToNextStep()
                        }
                    case .complete:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .task {
            await checkInitialPermissions()
        }
    }
    
    private func checkInitialPermissions() async {
        // Update permission statuses
        microphoneManager.updatePermissionStatus()
        await notificationManager.updatePermissionStatus()
        
        // Wait a moment for the UI to settle
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            // Determine which permission to request first
            if microphoneManager.permissionStatus == AVAudioSession.RecordPermission.undetermined {
                currentPermissionStep = .microphone
                isCheckingPermissions = false
            } else if notificationManager.permissionStatus == .notDetermined {
                currentPermissionStep = .notification
                isCheckingPermissions = false
            } else {
                // All permissions already determined
                onComplete()
            }
        }
    }
    
    private func moveToNextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentPermissionStep {
            case .microphone:
                // Check if we need to request notifications
                if notificationManager.permissionStatus == .notDetermined {
                    currentPermissionStep = .notification
                } else {
                    currentPermissionStep = .complete
                    onComplete()
                }
            case .notification:
                currentPermissionStep = .complete
                onComplete()
            case .complete:
                onComplete()
            }
        }
    }
}

@available(iOS 15.0, *)
struct MicrophonePermissionRequestView: View {
    @StateObject private var permissionManager = MicrophonePermissionManager.shared
    @State private var showAlert = false
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon with animation
            ZStack {
                Circle()
                    .fill(ColorTheme.primaryAccent.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 56))
                    .foregroundColor(ColorTheme.primaryAccent)
            }
            
            VStack(spacing: 16) {
                Text("Microphone Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Inkra needs microphone access to record your interviews and voice logs")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    Task {
                        let granted = await permissionManager.requestMicrophonePermission()
                        if granted {
                            onComplete()
                        } else {
                            showAlert = true
                        }
                    }
                }) {
                    Text("Allow Microphone Access")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                
                Button(action: onComplete) {
                    Text("Not Now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.bottom, 50)
        }
        .alert("Microphone Access Required", isPresented: $showAlert) {
            Button("Open Settings") {
                permissionManager.openSettings()
                onComplete()
            }
            Button("Continue Without", role: .cancel) {
                onComplete()
            }
        } message: {
            Text("Microphone access is required for recording interviews. You can enable it later in Settings.")
        }
    }
}

@available(iOS 15.0, *)
struct NotificationPermissionRequestView: View {
    @StateObject private var permissionManager = NotificationPermissionManager.shared
    @State private var showAlert = false
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon with animation
            ZStack {
                Circle()
                    .fill(ColorTheme.secondaryAccent.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56))
                    .foregroundColor(ColorTheme.secondaryAccent)
            }
            
            VStack(spacing: 16) {
                Text("Stay Updated")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Get notified when your exports are ready and receive helpful reminders")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    Task {
                        _ = await permissionManager.requestNotificationPermission()
                        onComplete()
                    }
                }) {
                    Text("Enable Notifications")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                
                Button(action: onComplete) {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.bottom, 50)
        }
        .alert("Notifications Disabled", isPresented: $showAlert) {
            Button("Open Settings") {
                permissionManager.openSettings()
                onComplete()
            }
            Button("Continue", role: .cancel) {
                onComplete()
            }
        } message: {
            Text("You can enable notifications anytime in Settings to get updates about your content.")
        }
    }
}