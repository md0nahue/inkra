import Foundation
import Combine

protocol AudioServiceProtocol {
    func requestUploadURL(projectId: Int, fileName: String, mimeType: String, duration: TimeInterval, questionId: Int?) async throws -> UploadResponse
    func uploadAudio(data: Data, to uploadURL: String) async throws
    func notifyUploadComplete(projectId: Int, audioSegmentId: Int, success: Bool, errorMessage: String?) async throws -> StandardAPIResponse
    func getPlaybackURL(projectId: Int, audioSegmentId: Int) async throws -> PlaybackResponse
}

class AudioService: ObservableObject, AudioServiceProtocol {
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.networkService = networkService
    }
    
    func requestUploadURL(projectId: Int, fileName: String, mimeType: String, duration: TimeInterval, questionId: Int?) async throws -> UploadResponse {
        let request = AudioUploadRequest(
            fileName: fileName,
            mimeType: mimeType,
            recordedDurationSeconds: duration,
            questionId: questionId
        )
        let endpoint = AudioEndpoint.requestUpload(projectId, request)
        return try await networkService.request(endpoint, responseType: UploadResponse.self)
    }
    
    func uploadAudio(data: Data, to uploadURL: String) async throws {
        guard let url = URL(string: uploadURL) else {
            throw NetworkError.invalidURL
        }
        try await networkService.upload(data: data, to: url)
    }
    
    func notifyUploadComplete(projectId: Int, audioSegmentId: Int, success: Bool, errorMessage: String?) async throws -> StandardAPIResponse {
        let request = UploadCompleteRequest(
            audioSegmentId: audioSegmentId,
            uploadStatus: success ? "success" : "failed",
            errorMessage: errorMessage
        )
        let endpoint = AudioEndpoint.uploadComplete(projectId, request)
        return try await networkService.request(endpoint, responseType: StandardAPIResponse.self)
    }
    
    func getPlaybackURL(projectId: Int, audioSegmentId: Int) async throws -> PlaybackResponse {
        let endpoint = AudioEndpoint.playbackURL(projectId, audioSegmentId)
        return try await networkService.request(endpoint, responseType: PlaybackResponse.self)
    }
}

enum AudioEndpoint: APIEndpoint {
    case requestUpload(Int, AudioUploadRequest)
    case uploadComplete(Int, UploadCompleteRequest)
    case playbackURL(Int, Int) // projectId, audioSegmentId
    
    var path: String {
        switch self {
        case .requestUpload(let projectId, _):
            return "/api/projects/\(projectId)/audio_segments/upload_request"
        case .uploadComplete(let projectId, _):
            return "/api/projects/\(projectId)/audio_segments/upload_complete"
        case .playbackURL(let projectId, let audioSegmentId):
            return "/api/projects/\(projectId)/audio_segments/\(audioSegmentId)/playback_url"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .requestUpload, .uploadComplete:
            return .POST
        case .playbackURL:
            return .GET
        }
    }
    
    var body: Codable? {
        switch self {
        case .requestUpload(_, let request):
            return request
        case .uploadComplete(_, let request):
            return request
        case .playbackURL:
            return nil
        }
    }
}