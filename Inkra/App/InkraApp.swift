import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// App Delegate for handling background tasks
#if canImport(UIKit)
@available(iOS 15.0, *)
class AppDelegate: NSObject, UIApplicationDelegate {
    var backgroundSessionCompletionHandler: (() -> Void)?
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        backgroundSessionCompletionHandler = completionHandler
        BackgroundUploadService.shared.handleBackgroundURLSession(identifier: identifier, completionHandler: completionHandler)
    }
}
#endif

@available(iOS 15.0, macOS 11.0, *)
@main
struct InkraApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    // Get the scenePhase from the environment
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var dataManager = DataManager.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var networkConnectivityService = NetworkConnectivityService.shared
    @StateObject private var audioDeviceManager = AudioDeviceManager.shared
    
    init() {
        // Initialize logging system
        initializeLogging()
        
        #if DEBUG
        ErrorLogger.shared.printLogFilePath()
        ErrorLogger.shared.logSessionStart()
        #endif
    }
    
    private func initializeLogging() {
        // Log app startup
        LogManager.shared.info("App launched - Environment: \(AppConfig.environment)")
        LogManager.shared.info("API Base URL: \(AppConfig.apiBaseURL)")
        
        // Check if we should upload logs automatically (staging builds)
        if AppConfig.shouldUploadLogs {
            LogManager.shared.info("Automatic log upload enabled for staging build")
            
            // Schedule periodic log uploads for staging builds
            Task {
                await schedulePeriodicLogUploads()
            }
        }
    }
    
    private func schedulePeriodicLogUploads() async {
        // Upload logs every 30 minutes in staging builds
        guard AppConfig.shouldUploadLogs else { return }
        
        while true {
            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000) // 30 minutes
            
            LogManager.shared.info("Performing periodic log upload")
            await LogUploader.shared.uploadAllLogs(logType: .automatic)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(syncService)
                .environmentObject(networkConnectivityService)
                .environmentObject(audioDeviceManager)
                .preferredColorScheme(.dark)
                .tint(ColorTheme.primaryAccent)
                .deviceToast()
                .task {
                    // Perform initial sync when app launches
                    await syncService.performInitialSync()
                    
                    // Offline upload service removed during refactor
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .background:
                        // Offline upload service removed during refactor
                        break
                    case .active:
                        // Offline upload service removed during refactor
                        break
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
