import Foundation

struct AudioSegment: Codable, Identifiable, Equatable {
    let id: Int
    let fileName: String
    let mimeType: String
    let recordedDurationSeconds: TimeInterval
    let questionId: Int?
    let uploadUrl: String?
    let uploadStatus: UploadStatus
    let expiresAt: Date?
    
    enum UploadStatus: String, Codable {
        case pending = "pending"
        case uploading = "uploading"
        case success = "success"
        case failed = "failed"
    }
}

struct AudioSegmentInfo {
    let questionId: Int
    let localURL: URL?
    let duration: TimeInterval
    let audioSegmentId: Int?
    let isUploaded: Bool
    let textResponse: String?
    
    init(questionId: Int, localURL: URL?, duration: TimeInterval = 0, audioSegmentId: Int? = nil, isUploaded: Bool = false, textResponse: String? = nil) {
        self.questionId = questionId
        self.localURL = localURL
        self.duration = duration
        self.audioSegmentId = audioSegmentId
        self.isUploaded = isUploaded
        self.textResponse = textResponse
    }
}

