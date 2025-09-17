import Foundation

// IMPORTANT: DO NOT add explicit CodingKeys to this struct!
// NetworkService has .convertFromSnakeCase globally configured.
// Explicit CodingKeys override the automatic conversion and cause decoding errors.
// The backend sends: project_id, last_updated, raw_content, etc.
// These automatically map to: projectId, lastUpdated, rawContent, etc.
struct Transcript: Codable, Identifiable, Equatable {
    let id: Int
    let projectId: Int
    let status: TranscriptStatus?
    let lastUpdated: Date?
    let rawContent: String?
    let polishedContent: String? // Renamed from polishedContentText to match API
    let editedContent: [TranscriptContent]
    let rawStructuredContent: [TranscriptContent]?
    
    enum TranscriptStatus: String, Codable {
        case processingRaw = "processing_raw"
        case rawReady = "raw_ready"
        case editing = "editing"
        case ready = "ready"
        case failed = "failed"
    }
    
    
    // Computed property for getting text content - prefers polished, falls back to structured
    var textContent: String? {
        if let polishedText = polishedContent, !polishedText.isEmpty {
            return polishedText
        }
        
        guard !editedContent.isEmpty else { return nil }
        return editedContent
            .compactMap { content in
                switch content.type {
                case .chapter:
                    return content.title.map { "\($0)\n\n" }
                case .section:
                    return content.title.map { "\($0)\n\n" }
                case .paragraph:
                    return content.text.map { "\($0)\n\n" }
                }
            }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// IMPORTANT: DO NOT add explicit CodingKeys to this struct!
// Let NetworkService's .convertFromSnakeCase handle the conversion.
struct TranscriptContent: Codable, Identifiable, Equatable {
    let id: UUID = UUID() // Generate ID locally
    let type: ContentType
    let chapterId: Int?
    let sectionId: Int?
    let questionId: Int?
    let title: String?
    let text: String?
    let audioSegmentId: Int?
    
    init(type: ContentType, chapterId: Int? = nil, sectionId: Int? = nil, questionId: Int? = nil, title: String? = nil, text: String? = nil, audioSegmentId: Int? = nil) {
        self.type = type
        self.chapterId = chapterId
        self.sectionId = sectionId
        self.questionId = questionId
        self.title = title
        self.text = text
        self.audioSegmentId = audioSegmentId
    }
    
    // Custom decoding to handle ID generation
    enum CodingKeys: String, CodingKey {
        case type
        case chapterId
        case sectionId
        case questionId
        case title
        case text
        case audioSegmentId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(ContentType.self, forKey: .type)
        self.chapterId = try container.decodeIfPresent(Int.self, forKey: .chapterId)
        self.sectionId = try container.decodeIfPresent(Int.self, forKey: .sectionId)
        self.questionId = try container.decodeIfPresent(Int.self, forKey: .questionId)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.audioSegmentId = try container.decodeIfPresent(Int.self, forKey: .audioSegmentId)
    }
    
    enum ContentType: String, Codable {
        case chapter = "chapter"
        case section = "section"
        case paragraph = "paragraph"
    }
    
}