import Foundation

/// Service to track the timestamp of the latest questions for each project
class QuestionTimestampService {
    static let shared = QuestionTimestampService()
    
    private init() {}
    
    private let timestampKey = "latest_questions_timestamp"
    
    /// Get the timestamp of the most recent question for a project
    func getLatestQuestionTimestamp(for projectId: Int) -> Date {
        let key = "\(timestampKey)_\(projectId)"
        
        if let timestamp = UserDefaults.standard.object(forKey: key) as? Date {
            return timestamp
        } else {
            // If no timestamp is stored, return a date from the past to ensure we get all questions
            return Date(timeIntervalSince1970: 0)
        }
    }
    
    /// Update the timestamp for a project with the newest question timestamp
    func updateLatestQuestionTimestamp(for projectId: Int, timestamp: Date) {
        let key = "\(timestampKey)_\(projectId)"
        UserDefaults.standard.set(timestamp, forKey: key)
    }
    
    /// Update the timestamp for a project to the current time
    func updateLatestQuestionTimestamp(for projectId: Int) {
        updateLatestQuestionTimestamp(for: projectId, timestamp: Date())
    }
    
    /// Clear the timestamp for a project
    func clearTimestamp(for projectId: Int) {
        let key = "\(timestampKey)_\(projectId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// Clear all timestamps
    func clearAllTimestamps() {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        
        for key in keys {
            if key.hasPrefix(timestampKey) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}