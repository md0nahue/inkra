import Foundation

struct Project: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let title: String
    let createdAt: Date
    let lastModifiedAt: Date
    let lastAccessedAt: Date?
    let preset: ProjectPresetInfo?
    var outline: Outline?
    let isSpeechInterview: Bool?
    let presetId: Int?
    let isOffline: Bool?
    
    // Computed property to derive status from outline status
    var status: ProjectStatus {
        guard let outline = outline else { return .outlineGenerating }
        
        switch outline.status {
        case .notStarted:
            return .outlineGenerating
        case .generating:
            return .outlineGenerating
        case .ready:
            return .outlineReady
        case .failed:
            return .failed
        }
    }
    
    // Computed property to calculate estimated interview time (30 seconds per question)
    var estimatedInterviewTime: TimeInterval {
        guard let outline = outline else { return 0 }
        
        let totalQuestions = outline.chapters
            .filter { !$0.omitted }
            .flatMap { $0.sections }
            .filter { !$0.omitted }
            .flatMap { $0.questions }
            .filter { !$0.omitted }
            .count
        
        return TimeInterval(totalQuestions * 30) // 30 seconds per question
    }
    
    // Computed property to get total question count
    var totalQuestionCount: Int {
        guard let outline = outline else { return 0 }
        
        return outline.chapters
            .filter { !$0.omitted }
            .flatMap { $0.sections }
            .filter { !$0.omitted }
            .flatMap { $0.questions }
            .filter { !$0.omitted }
            .count
    }
    
    // Helper to format estimated time as a string
    var formattedEstimatedTime: String {
        let time = estimatedInterviewTime
        let minutes = Int(time / 60)
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        
        if minutes == 0 {
            return "\(seconds) seconds"
        } else if seconds == 0 {
            return "\(minutes) minutes"
        } else {
            return "\(minutes) minutes, \(seconds) seconds"
        }
    }
    
    enum ProjectStatus: String, Codable, CaseIterable {
        case outlineGenerating = "outline_generating"
        case outlineReady = "outline_ready"
        case recordingInProgress = "recording_in_progress"
        case transcribing = "transcribing"
        case completed = "completed"
        case failed = "failed"
    }
}

struct Outline: Codable, Equatable, Hashable {
    let status: OutlineStatus
    var chapters: [Chapter]
    
    enum OutlineStatus: String, Codable {
        case notStarted = "not_started"
        case ready = "ready"
        case generating = "generating"
        case failed = "failed"
    }
}