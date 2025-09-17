import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol BackgroundTaskManagerProtocol {
    func beginBackgroundTask(name: String, completion: @escaping () -> Void) -> Int
    func endBackgroundTask(_ identifier: Int)
}

#if canImport(UIKit)
class BackgroundTaskManager: BackgroundTaskManagerProtocol {
    static let shared = BackgroundTaskManager()
    
    private var activeTasks: [Int: UIBackgroundTaskIdentifier] = [:]
    private var taskCounter = 0
    
    private init() {}
    
    func beginBackgroundTask(name: String, completion: @escaping () -> Void) -> Int {
        let taskId = taskCounter
        taskCounter += 1
        
        let backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: name) {
            // System will call this if the background time expires
            print("⏰ Background task \(name) expired, finishing...")
            completion()
            self.endBackgroundTask(taskId)
        }
        
        if backgroundTaskId != .invalid {
            activeTasks[taskId] = backgroundTaskId
            print("🔋 Started background task: \(name) (ID: \(taskId))")
        } else {
            print("❌ Failed to start background task: \(name)")
        }
        
        return taskId
    }
    
    func endBackgroundTask(_ identifier: Int) {
        guard let backgroundTaskId = activeTasks[identifier] else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        activeTasks.removeValue(forKey: identifier)
        
        print("✅ Ended background task (ID: \(identifier))")
    }
}
#else
// macOS fallback - no background task management needed
class BackgroundTaskManager: BackgroundTaskManagerProtocol {
    static let shared = BackgroundTaskManager()
    
    private init() {}
    
    func beginBackgroundTask(name: String, completion: @escaping () -> Void) -> Int {
        return 0 // No-op on macOS
    }
    
    func endBackgroundTask(_ identifier: Int) {
        // No-op on macOS
    }
}
#endif

// MARK: - Enhanced Background Upload Service

extension BackgroundUploadService {
    private var backgroundTaskManager: BackgroundTaskManagerProtocol {
        return BackgroundTaskManager.shared
    }
    
    func uploadAudioWithBackgroundTask(data: Data, to uploadURL: String, for questionId: Int) async throws {
        let taskId = backgroundTaskManager.beginBackgroundTask(name: "AudioUpload-\(questionId)") {
            print("⏰ Background upload task for question \(questionId) expired")
        }
        
        defer {
            backgroundTaskManager.endBackgroundTask(taskId)
        }
        
        try await uploadAudio(data: data, to: uploadURL, for: questionId)
    }
}

