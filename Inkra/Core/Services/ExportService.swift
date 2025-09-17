import Foundation

protocol ExportServiceProtocol {
    func exportContent(projectId: Int, format: String, includeOutline: Bool, includeTranscript: Bool, transcriptVersion: String, includeQuestions: Bool) async throws -> ExportResponse
    func getExportPreview(projectId: Int) async throws -> ExportPreviewResponse
    func exportConcatenatedAudio(projectId: Int, format: String, includeQuestionNumbers: Bool, includeTimestamps: Bool, segmentOrder: String) async throws -> ConcatenatedAudioResponse
    func getAudioExportStatus(projectId: Int, exportId: String) async throws -> ConcatenatedAudioResponse
}

class ExportService: ExportServiceProtocol {
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.networkService = networkService
    }
    
    func exportContent(projectId: Int, format: String, includeOutline: Bool, includeTranscript: Bool, transcriptVersion: String, includeQuestions: Bool) async throws -> ExportResponse {
        let request = ProjectExportRequest(
            format: format,
            includeOutline: includeOutline,
            includeTranscript: includeTranscript,
            transcriptVersion: transcriptVersion,
            includeQuestions: includeQuestions
        )
        let endpoint = ExportEndpoint.export(projectId, request)
        return try await networkService.request(endpoint, responseType: ExportResponse.self)
    }
    
    func getExportPreview(projectId: Int) async throws -> ExportPreviewResponse {
        let endpoint = ExportEndpoint.preview(projectId)
        return try await networkService.request(endpoint, responseType: ExportPreviewResponse.self)
    }
    
    func exportConcatenatedAudio(projectId: Int, format: String, includeQuestionNumbers: Bool, includeTimestamps: Bool, segmentOrder: String) async throws -> ConcatenatedAudioResponse {
        let request = AudioConcatenationRequest(
            projectId: projectId,
            format: format,
            includeQuestionNumbers: includeQuestionNumbers,
            includeTimestamps: includeTimestamps,
            segmentOrder: segmentOrder
        )
        let endpoint = ExportEndpoint.concatenateAudio(projectId, request)
        return try await networkService.request(endpoint, responseType: ConcatenatedAudioResponse.self)
    }
    
    func getAudioExportStatus(projectId: Int, exportId: String) async throws -> ConcatenatedAudioResponse {
        let endpoint = ExportEndpoint.audioExportStatus(projectId, exportId)
        return try await networkService.request(endpoint, responseType: ConcatenatedAudioResponse.self)
    }
}

enum ExportEndpoint: APIEndpoint {
    case export(Int, ProjectExportRequest)
    case preview(Int)
    case concatenateAudio(Int, AudioConcatenationRequest)
    case audioExportStatus(Int, String)
    
    var path: String {
        switch self {
        case .export(let projectId, _):
            return "/api/projects/\(projectId)/export"
        case .preview(let projectId):
            return "/api/projects/\(projectId)/export/preview"
        case .concatenateAudio(let projectId, _):
            return "/api/projects/\(projectId)/audio/concatenate"
        case .audioExportStatus(let projectId, let exportId):
            return "/api/projects/\(projectId)/audio/exports/\(exportId)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .export, .concatenateAudio:
            return .POST
        case .preview, .audioExportStatus:
            return .GET
        }
    }
    
    var body: Codable? {
        switch self {
        case .export(_, let request):
            return request
        case .concatenateAudio(_, let request):
            return request
        case .preview, .audioExportStatus:
            return nil
        }
    }
}