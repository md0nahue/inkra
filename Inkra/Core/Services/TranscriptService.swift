import Foundation

protocol TranscriptServiceProtocol {
    func getTranscript(projectId: Int) async throws -> Transcript
    func updateTranscript(projectId: Int, polishedContent: String, editedContent: [TranscriptContent]?) async throws -> TranscriptUpdateResponse
}

struct TranscriptUpdateResponse: Codable {
    let id: Int
    let projectId: Int
    let status: String
    let lastUpdated: String
    let message: String
}

class TranscriptService: TranscriptServiceProtocol {
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.networkService = networkService
    }
    
    func getTranscript(projectId: Int) async throws -> Transcript {
        let endpoint = TranscriptEndpoint.get(projectId)
        return try await networkService.request(endpoint, responseType: Transcript.self)
    }
    
    func updateTranscript(projectId: Int, polishedContent: String, editedContent: [TranscriptContent]?) async throws -> TranscriptUpdateResponse {
        let endpoint = TranscriptEndpoint.update(projectId, polishedContent, editedContent)
        return try await networkService.request(endpoint, responseType: TranscriptUpdateResponse.self)
    }
}

struct TranscriptUpdateRequest: Codable {
    let polishedContent: String
    // Remove editedContent for now since it's not being used and causes issues
    // let editedContent: [[String: Any]]?
}

enum TranscriptEndpoint: APIEndpoint {
    case get(Int)
    case update(Int, String, [TranscriptContent]?)
    
    var path: String {
        switch self {
        case .get(let projectId), .update(let projectId, _, _):
            return "/api/projects/\(projectId)/transcript"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .get:
            return .GET
        case .update:
            return .PATCH
        }
    }
    
    var body: Codable? {
        switch self {
        case .get:
            return nil
        case .update(_, let polishedContent, _):
            // For now, only send the polished content
            // The edited content functionality can be added later when needed
            return TranscriptUpdateRequest(polishedContent: polishedContent)
        }
    }
}

