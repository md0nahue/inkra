import Foundation

// IMPORTANT: This struct uses camelCase properties that are automatically
// converted to snake_case by NetworkService's JSONEncoder.keyEncodingStrategy.
// The Rails backend expects: initial_topic, is_speech_interview, preset_id, etc.
// There has been a recurring issue with this conversion, so the Rails controller
// now defensively checks for BOTH snake_case AND camelCase versions.
// DO NOT add explicit CodingKeys here - let the automatic conversion handle it.
struct CreateProjectRequest: Codable {
    let initialTopic: String
    let isSpeechInterview: Bool?
    let presetId: Int? // Keep for legacy support
    let presetUuid: String? // New UUID-based identifier
    let voiceId: String?
    let speechRate: Int?
    let interviewLength: String? // "5_minutes", "10_minutes", "20_minutes", "unlimited"
    let questionCount: Int? // Number of questions to generate
}

struct CreateProjectResponse: Codable {
    let projectId: Int
    let title: String
    let createdAt: Date
    
    // CODING KEYS PERMANENTLY REMOVED: 
    // Explicit CodingKeys conflict with NetworkService's global .convertFromSnakeCase strategy,
    // causing "Key 'project_id' not found" errors despite the key being present in JSON.
    // The global strategy automatically maps snake_case JSON keys (project_id, created_at) 
    // to camelCase Swift properties (projectId, createdAt). Never add CodingKeys back.
}

struct ProjectListResponse: Codable {
    let projects: [ProjectSummary]
}

struct ProjectSummary: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let topic: String
    let createdAt: Date
    let lastModifiedAt: Date
    let lastAccessedAt: Date?
    let preset: ProjectPresetInfo?
    let outline: OutlineSummary
    let isSpeechInterview: Bool?
}

struct ProjectPresetInfo: Codable, Hashable {
    let title: String
    let iconName: String
    let category: String
}

struct OutlineSummary: Codable, Hashable {
    let status: String
    let chaptersCount: Int
    let sectionsCount: Int
    let questionsCount: Int
    let baseQuestionsCount: Int
    let followupQuestionsCount: Int
    let answeredQuestionsCount: Int?
}

struct UpdateOutlineRequest: Codable {
    let updates: [OutlineUpdate]
}

struct OutlineUpdate: Codable {
    let chapterId: Int?
    let sectionId: Int?
    let questionId: Int?
    let omitted: Bool
}

struct StandardAPIResponse: Codable {
    let message: String
    let projectId: Int?
}

struct AddMoreChaptersResponse: Codable {
    let message: String
    let projectId: Int
    let newChapters: [Chapter]
    let totalChaptersCount: Int
}

struct AddChapterRequest: Codable {
    let title: String
}

struct UpdateInterviewModeRequest: Codable {
    let isSpeechInterview: Bool
}

struct FollowUpQuestionsResponse: Codable {
    let projectId: Int
    let since: String
    let newQuestions: [InterviewQuestion]
    let count: Int
    let generatedAt: String
}

struct InterviewQuestion: Codable, Identifiable, Equatable, Hashable {
    let questionId: Int
    let text: String
    let order: Int
    let omitted: Bool
    let skipped: Bool
    let parentQuestionId: Int?
    let isFollowUp: Bool
    let sectionId: Int
    let sectionTitle: String
    let chapterId: Int
    let chapterTitle: String
    let pollyAudioUrl: String?
    
    var id: Int { questionId }
    
    // Convert to basic Question for compatibility
    var asQuestion: Question {
        Question(
            questionId: questionId,
            text: text,
            order: order,
            omitted: omitted,
            skipped: skipped,
            parentQuestionId: parentQuestionId,
            isFollowUp: isFollowUp
        )
    }
}

struct AvailableQuestionsResponse: Codable {
    let projectId: Int
    let questions: [InterviewQuestion]
    let totalQuestions: Int
    let generatedAt: String
    let status: String?
}

struct QuestionsDiffResponse: Codable {
    let projectId: Int
    let since: String
    let currentTime: String
    let newQuestionsCount: Int
    let questions: [InterviewQuestion]
    let hasMore: Bool
}

// Question with actual interview response
struct InterviewQuestionWithResponse: Codable, Identifiable, Equatable, Hashable {
    let questionId: Int
    let text: String
    let order: Int
    let omitted: Bool
    let skipped: Bool
    let parentQuestionId: Int?
    let isFollowUp: Bool
    let sectionId: Int
    let sectionTitle: String
    let chapterId: Int
    let chapterTitle: String
    let pollyAudioUrl: String?
    
    // Response data
    let hasResponse: Bool
    let responseStatus: String?
    let transcribedResponse: String?
    let audioFileName: String?
    let responseDuration: TimeInterval?
    
    var id: Int { questionId }
    
    // Convert to basic Question for compatibility
    var asQuestion: Question {
        Question(
            questionId: questionId,
            text: text,
            order: order,
            omitted: omitted,
            skipped: skipped,
            parentQuestionId: parentQuestionId,
            isFollowUp: isFollowUp
        )
    }
}

struct QuestionsWithResponsesResponse: Codable {
    let projectId: Int
    let projectTitle: String
    let status: String
    let questions: [InterviewQuestionWithResponse]
    let totalQuestions: Int
    let questionsWithResponses: Int
    let questionsWithTranscriptions: Int
    let generatedAt: String
}

struct APIError: Codable, Error {
    let message: String
    let code: String?
    let details: [String: String]?
}

// Transcript Models - moved to Transcript.swift

struct AudioSegmentSummary: Codable {
    let id: Int
    let fileName: String
    let duration: TimeInterval?
    let transcriptionStatus: String
    let questionId: Int?
}

// Export Models
struct ProjectExportRequest: Codable {
    let format: String // "pdf", "docx", "txt", "csv"
    let includeOutline: Bool
    let includeTranscript: Bool
    let transcriptVersion: String // "raw" or "edited"
    let includeQuestions: Bool
}

struct ExportResponse: Codable {
    let exportUrl: String
    let expiresAt: Date
    let format: String
    let fileName: String
}


// Audio Concatenation Export Models
struct AudioConcatenationRequest: Codable {
    let projectId: Int
    let format: String // "m4a", "mp3", "wav"
    let includeQuestionNumbers: Bool
    let includeTimestamps: Bool
    let segmentOrder: String // "chronological", "question_order"
}

struct ConcatenatedAudioResponse: Codable {
    let audioUrl: String
    let expiresAt: Date
    let format: String
    let fileName: String
    let totalDuration: TimeInterval
    let segmentsIncluded: Int
    let processingStatus: String // "completed", "processing", "failed"
}

// Question Models - moved to Question.swift

// Audio Upload/Playback Models
struct AudioUploadRequest: Codable {
    let fileName: String
    let mimeType: String
    let recordedDurationSeconds: TimeInterval
    let questionId: Int?
}

struct UploadResponse: Codable {
    let audioSegmentId: Int
    let uploadUrl: String
    let expiresAt: Date
}

struct UploadCompleteRequest: Codable {
    let audioSegmentId: Int
    let uploadStatus: String
    let errorMessage: String?
}

struct PlaybackResponse: Codable {
    let playbackUrl: String
    let expiresAt: Date
    let duration: TimeInterval?
    let fileName: String
}

struct UpdateUserPreferencesRequest: Codable {
    let userPreferences: UserPreferencesData
}

struct UserPreferencesData: Codable {
    let interests: [String]
}

struct UserPreferencesResponse: Codable {
    let interests: [String]
    let message: String?
}

// Feedback Models
struct CreateFeedbackRequest: Codable {
    let feedbackText: String
    let feedbackType: String
    let email: String?
}

struct FeedbackResponse: Codable {
    let id: Int
    let message: String
    let feedbackType: String
    let createdAt: Date
}

struct FeedbackListResponse: Codable {
    let feedbacks: [FeedbackSummary]
}

struct FeedbackSummary: Codable, Identifiable {
    let id: Int
    let feedbackText: String
    let feedbackType: String
    let resolved: Bool
    let createdAt: Date
}

// MARK: - Shareable Links

struct UpdateShareSettingsRequest: Codable {
    let isPublic: Bool
    let publicTitle: String?
    let publicDescription: String?
}

struct ShareSettingsResponse: Codable {
    let projectId: Int
    let isPublic: Bool
    let publicTitle: String?
    let publicDescription: String?
    let shareableToken: String
    let shareableUrl: String?
    let shortShareableUrl: String?
    let readyForSharing: Bool
}

struct ShareUrlResponse: Codable {
    let projectId: Int
    let title: String
    let description: String?
    let shareableToken: String
    let shareableUrl: String?
    let shortShareableUrl: String?
    let readyForSharing: Bool
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int)
    case unauthorized
    case networkUnavailable
    case timeout
    case validationError(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            #if DEBUG
            return "Failed to decode response: \(error.localizedDescription). Check error log for details."
            #else
            return "Invalid response from server. Please try again."
            #endif
        case .serverError(let code):
            return "Server error (\(code))"
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .networkUnavailable:
            return "Network unavailable"
        case .timeout:
            return "Request timed out"
        case .validationError(let message):
            return message
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - User Lifecycle Models

struct DataExportRequest: Codable {
    // No parameters needed for new approach
}

struct DataExportResponse: Codable {
    let message: String
    let exportId: Int?
    let status: String?
    let createdAt: Date?
    let error: String?
    let daysUntilNextExport: Int?
    let lastExportDate: Date?
}

struct DeleteAccountRequest: Codable {
    let experienceDescription: String
    let whatWouldChange: String?
    let requestExport: Bool
}

struct DeleteAccountResponse: Codable {
    let message: String
    let deletionScheduled: Bool
    let exportRequested: Bool
}

struct ExportStatusResponse: Codable {
    let userId: Int
    let email: String
    let hasExport: Bool
    let exportId: Int?
    let status: String?
    let createdAt: Date?
    let expiresAt: Date?
    let fileCount: Int?
    let fileSize: String?
    let daysUntilExpiration: Int?
    let dataIsStale: Bool?
    let canCreateNew: Bool
    let downloadUrl: String?
    let shareUrl: String?
    let message: String?
}