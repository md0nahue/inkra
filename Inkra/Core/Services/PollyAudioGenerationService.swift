import Foundation

protocol PollyAudioGenerationServiceProtocol {
    func generateAllAudio(projectId: Int, voiceId: String, speechRate: Int) async throws -> PollyGenerationResponse
    func generateMissingAudio(projectId: Int, voiceId: String, speechRate: Int) async throws -> PollyGenerationResponse
    func updateVoiceSettings(projectId: Int, voiceId: String, speechRate: Int) async throws -> PollyGenerationResponse
    func getGenerationStatus(projectId: Int) async throws -> PollyStatusResponse
    func getAvailableVoices() async throws -> PollyVoicesResponse
    func cleanupFailedClips(projectId: Int) async throws -> PollyCleanupResponse
}

@available(iOS 15.0, macOS 11.0, *)
class PollyAudioGenerationService: PollyAudioGenerationServiceProtocol {
    private let networkService: NetworkServiceProtocol
    
    static let shared = PollyAudioGenerationService()
    
    init(networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.networkService = networkService
    }
    
    func generateAllAudio(projectId: Int, voiceId: String = "Matthew", speechRate: Int = 100) async throws -> PollyGenerationResponse {
        let request = PollyGenerationRequest(voiceId: voiceId, speechRate: speechRate)
        let endpoint = PollyAudioEndpoint.generateAll(projectId, request)
        
        do {
            return try await networkService.request(endpoint, responseType: PollyGenerationResponse.self)
        } catch {
            // Enhanced error context for debugging
            if let networkError = error as? NetworkError,
               case .decodingError(_) = networkError {
                print("❌ Polly generation decoding error for project \(projectId) - check API contract documentation")
            }
            throw error
        }
    }
    
    func generateMissingAudio(projectId: Int, voiceId: String = "Matthew", speechRate: Int = 100) async throws -> PollyGenerationResponse {
        let request = PollyGenerationRequest(voiceId: voiceId, speechRate: speechRate)
        let endpoint = PollyAudioEndpoint.generateMissing(projectId, request)
        return try await networkService.request(endpoint, responseType: PollyGenerationResponse.self)
    }
    
    func updateVoiceSettings(projectId: Int, voiceId: String, speechRate: Int) async throws -> PollyGenerationResponse {
        let request = PollyGenerationRequest(voiceId: voiceId, speechRate: speechRate)
        let endpoint = PollyAudioEndpoint.updateVoiceSettings(projectId, request)
        return try await networkService.request(endpoint, responseType: PollyGenerationResponse.self)
    }
    
    func getGenerationStatus(projectId: Int) async throws -> PollyStatusResponse {
        let endpoint = PollyAudioEndpoint.status(projectId)
        return try await networkService.request(endpoint, responseType: PollyStatusResponse.self)
    }
    
    func getAvailableVoices() async throws -> PollyVoicesResponse {
        let endpoint = PollyAudioEndpoint.voices
        return try await networkService.request(endpoint, responseType: PollyVoicesResponse.self)
    }
    
    func cleanupFailedClips(projectId: Int) async throws -> PollyCleanupResponse {
        let endpoint = PollyAudioEndpoint.cleanupFailed(projectId)
        return try await networkService.request(endpoint, responseType: PollyCleanupResponse.self)
    }
    
    // Trigger automatic generation when a speech interview project is created
    func triggerInitialGeneration(projectId: Int, voiceId: String, speechRate: Int) async {
        do {
            print("🎵 Triggering initial Polly audio generation for project \(projectId)")
            let response = try await generateAllAudio(projectId: projectId, voiceId: voiceId, speechRate: speechRate)
            if let summary = response.generationSummary {
                print("✅ Initial Polly audio generation completed: \(summary.successCount) successes, \(summary.errorCount) errors")
            } else {
                print("✅ Initial Polly audio generation completed")
            }
        } catch {
            print("❌ Failed to generate initial Polly audio: \(error)")
            
            // Enhanced error logging for debugging
            if let networkError = error as? NetworkError {
                switch networkError {
                case .decodingError(let decodingError):
                    print("❌ Decoding error details: \(decodingError)")
                    print("💡 Suggestion: Check that the Rails API response includes all required fields (project_id, voice_id, etc.)")
                case .serverError(let code):
                    print("❌ Server error \(code) during Polly generation")
                case .networkUnavailable:
                    print("❌ Network unavailable during Polly generation")
                default:
                    print("❌ Network error during Polly generation: \(networkError.localizedDescription)")
                }
            }
        }
    }
    
    // Check if project is ready for offline speech interview
    func isReadyForOfflineInterview(projectId: Int) async -> Bool {
        do {
            let status = try await getGenerationStatus(projectId: projectId)
            return status.status.ready && status.status.completed > 0
        } catch {
            print("Failed to check offline readiness: \(error)")
            
            // Enhanced error logging for debugging
            if let networkError = error as? NetworkError {
                switch networkError {
                case .decodingError:
                    print("💡 Status check failed due to decoding error - API response may be malformed")
                case .serverError(let code):
                    print("💡 Status check failed due to server error \(code)")
                default:
                    print("💡 Status check failed: \(networkError.localizedDescription)")
                }
            }
            
            // Return false on any error to prevent crashes
            return false
        }
    }
}

// MARK: - API Endpoints

enum PollyAudioEndpoint: APIEndpoint {
    case generateAll(Int, PollyGenerationRequest)
    case generateMissing(Int, PollyGenerationRequest)
    case updateVoiceSettings(Int, PollyGenerationRequest)
    case status(Int)
    case voices
    case cleanupFailed(Int)
    
    var path: String {
        switch self {
        case .generateAll(let projectId, _):
            return "/api/projects/\(projectId)/polly_audio/generate_all"
        case .generateMissing(let projectId, _):
            return "/api/projects/\(projectId)/polly_audio/generate_missing"
        case .updateVoiceSettings(let projectId, _):
            return "/api/projects/\(projectId)/polly_audio/update_voice_settings"
        case .status(let projectId):
            return "/api/projects/\(projectId)/polly_audio/status"
        case .voices:
            return "/api/polly_audio/voices"
        case .cleanupFailed(let projectId):
            return "/api/projects/\(projectId)/polly_audio/cleanup_failed"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .generateAll, .generateMissing:
            return .POST
        case .updateVoiceSettings:
            return .PUT
        case .status, .voices:
            return .GET
        case .cleanupFailed:
            return .DELETE
        }
    }
    
    var body: Codable? {
        switch self {
        case .generateAll(_, let request), .generateMissing(_, let request), .updateVoiceSettings(_, let request):
            return request
        default:
            return nil
        }
    }
}

// MARK: - Data Models

struct PollyGenerationRequest: Codable {
    let voiceId: String
    let speechRate: Int
    
    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
        case speechRate = "speech_rate"
    }
}

// IMPORTANT: DO NOT add explicit CodingKeys here!
// The NetworkService JSONDecoder is configured with .convertFromSnakeCase
// which automatically converts snake_case JSON keys (e.g., project_id) to
// camelCase Swift properties (e.g., projectId).
// Adding explicit CodingKeys overrides this automatic conversion and causes
// decoding errors. This was causing the "project_id not found" error.
// Rails returns: project_id, voice_id, speech_rate, etc. (snake_case)
// Swift expects: projectId, voiceId, speechRate, etc. (camelCase)
// The automatic conversion handles this perfectly - no CodingKeys needed!
struct PollyGenerationResponse: Codable {
    let projectId: Int
    let voiceId: String
    let speechRate: Int
    let generationSummary: GenerationSummary?
    let generatedCount: Int?
    let regeneratedCount: Int?
    let generatedAt: String
}

struct GenerationSummary: Codable {
    let totalQuestions: Int
    let successCount: Int
    let errorCount: Int
}

struct PollyStatusResponse: Codable {
    let projectId: Int
    let status: GenerationStatus
    let costEstimate: CostEstimate
    let checkedAt: String
    
    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case status
        case costEstimate = "cost_estimate"
        case checkedAt = "checked_at"
    }
}

struct GenerationStatus: Codable {
    let ready: Bool
    let total: Int
    let completed: Int
    let failed: Int
    let generating: Int
    let pending: Int
    let missing: Int
}

struct CostEstimate: Codable {
    let questionsCount: Int
    let totalCharacters: Int
    let estimatedCost: Double
    
    enum CodingKeys: String, CodingKey {
        case questionsCount = "questions_count"
        case totalCharacters = "total_characters"
        case estimatedCost = "estimated_cost"
    }
}

// Note: PollyVoicesResponse and PollyVoice are defined in VoiceModels.swift

struct PollyCleanupResponse: Codable {
    let projectId: Int
    let cleanedUpCount: Int
    let cleanedAt: String
    
    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case cleanedUpCount = "cleaned_up_count"
        case cleanedAt = "cleaned_at"
    }
}