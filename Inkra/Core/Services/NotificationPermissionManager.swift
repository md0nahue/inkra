import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationPermissionManager: ObservableObject {
    static let shared = NotificationPermissionManager()
    
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var showPermissionAlert = false
    @Published var permissionDeniedAlert = false
    
    private init() {
        Task {
            await updatePermissionStatus()
        }
    }
    
    func updatePermissionStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            self.permissionStatus = settings.authorizationStatus
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.permissionStatus = granted ? .authorized : .denied
                if !granted {
                    self.permissionDeniedAlert = true
                }
            }
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            await MainActor.run {
                self.permissionStatus = .denied
                self.permissionDeniedAlert = true
            }
            return false
        }
    }
    
    func checkAndRequestPermissionIfNeeded() {
        Task {
            await updatePermissionStatus()
            
            switch permissionStatus {
            case .notDetermined:
                _ = await requestNotificationPermission()
            case .denied:
                await MainActor.run {
                    permissionDeniedAlert = true
                }
            case .authorized, .provisional, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }
    
    var hasPermission: Bool {
        return permissionStatus == .authorized || permissionStatus == .provisional
    }
    
    var needsPermission: Bool {
        return permissionStatus != .authorized && permissionStatus != .provisional
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

struct NotificationPermissionView: View {
    @StateObject private var permissionManager = NotificationPermissionManager.shared
    let onPermissionGranted: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundColor(ColorTheme.primaryAccent)
            
            VStack(spacing: 12) {
                Text("Enable Notifications")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Stay updated with interview reminders, export completions, and important updates about your content.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button("Allow Notifications") {
                    permissionManager.checkAndRequestPermissionIfNeeded()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                if permissionManager.needsPermission && permissionManager.permissionStatus != .notDetermined {
                    Button("Open Settings") {
                        permissionManager.openSettings()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Skip for Now") {
                    onPermissionGranted()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .onChange(of: permissionManager.permissionStatus) { newStatus in
            if permissionManager.hasPermission {
                onPermissionGranted()
            }
        }
        .onAppear {
            Task {
                await permissionManager.updatePermissionStatus()
            }
        }
        .alert("Notifications Disabled", isPresented: $permissionManager.permissionDeniedAlert) {
            Button("Settings") {
                permissionManager.openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive updates about your interviews and exports.")
        }
    }
}