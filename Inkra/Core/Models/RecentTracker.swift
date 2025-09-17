import Foundation

struct RecentTracker: Identifiable, Codable {
    let id: String
    let title: String
    let createdAt: Date
    let duration: TimeInterval?
    let transcriptionStatus: String
    
    init(id: String, title: String, createdAt: Date, duration: TimeInterval? = nil, transcriptionStatus: String = "pending") {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.transcriptionStatus = transcriptionStatus
    }
}