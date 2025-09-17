import Foundation
import Combine

@MainActor
class LambdaService: ObservableObject {
    static let shared = LambdaService()

    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Configuration
    private var apiGatewayBaseURL: String = ""
    private var authService = CognitoAuthService.shared

    // MARK: - Network Session
    private let urlSession: URLSession
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Rate Limiting
    @Published var dailyUsage: Int = 0
    @Published var dailyLimit: Int = 10
    @Published var isRateLimited = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        urlSession = URLSession(configuration: config)

        setupConfiguration()
    }

    // MARK: - Setup
    private func setupConfiguration() {
        // This will be configured from Terraform outputs
        apiGatewayBaseURL = ProcessInfo.processInfo.environment["API_GATEWAY_URL"] ??
                           "https://placeholder.execute-api.us-east-1.amazonaws.com/dev"

        print("🌐 Configured Lambda service with base URL: \(apiGatewayBaseURL)")
    }

    func configure(apiGatewayURL: String) {
        apiGatewayBaseURL = apiGatewayURL
        print("🔧 Lambda service reconfigured with URL: \(apiGatewayURL)")
    }

    // MARK: - Question Generation
    func generateQuestions(
        position: String,
        company: String,
        yearsOfExperience: String = "entry-level",
        difficulty: String = "medium",
        questionType: String = "behavioral"
    ) async throws -> QuestionGenerationResponse {

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let endpoint = "\(apiGatewayBaseURL)/questions/generate"

        guard let url = URL(string: endpoint) else {
            throw LambdaError.invalidURL(endpoint)
        }

        let requestBody = QuestionGenerationRequest(
            position: position,
            company: company,
            yearsOfExperience: yearsOfExperience,
            difficulty: difficulty,
            questionType: questionType
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header
        do {
            let idToken = try await authService.getIdToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        } catch {
            throw LambdaError.authenticationRequired
        }

        // Encode request body
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw LambdaError.encodingError(error)
        }

        // Perform request
        do {
            let (data, response) = try await urlSession.data(for: request)

            try validateResponse(response)

            let questionResponse = try JSONDecoder().decode(QuestionGenerationResponse.self, from: data)

            // Update rate limiting info
            self.dailyUsage = questionResponse.metadata?.dailyUsage ?? self.dailyUsage
            self.dailyLimit = questionResponse.metadata?.dailyLimit ?? self.dailyLimit

            print("✅ Generated \(questionResponse.questions.count) questions successfully")
            return questionResponse

        } catch let error as LambdaError {
            handleLambdaError(error)
            throw error
        } catch {
            let lambdaError = LambdaError.networkError(error)
            handleLambdaError(lambdaError)
            throw lambdaError
        }
    }

    // MARK: - User Profile Management
    func getUserProfile() async throws -> UserProfile {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let endpoint = "\(apiGatewayBaseURL)/user/profile"

        guard let url = URL(string: endpoint) else {
            throw LambdaError.invalidURL(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add authorization header
        do {
            let idToken = try await authService.getIdToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        } catch {
            throw LambdaError.authenticationRequired
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            try validateResponse(response)

            let userProfile = try JSONDecoder().decode(UserProfile.self, from: data)

            // Update local rate limiting info
            self.dailyUsage = userProfile.dailyUsage
            self.dailyLimit = userProfile.dailyLimit

            print("✅ Retrieved user profile successfully")
            return userProfile

        } catch let error as LambdaError {
            handleLambdaError(error)
            throw error
        } catch {
            let lambdaError = LambdaError.networkError(error)
            handleLambdaError(lambdaError)
            throw lambdaError
        }
    }

    func updateUserPreferences(_ preferences: UserPreferences) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let endpoint = "\(apiGatewayBaseURL)/user/preferences"

        guard let url = URL(string: endpoint) else {
            throw LambdaError.invalidURL(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header
        do {
            let idToken = try await authService.getIdToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        } catch {
            throw LambdaError.authenticationRequired
        }

        // Encode request body
        do {
            request.httpBody = try JSONEncoder().encode(preferences)
        } catch {
            throw LambdaError.encodingError(error)
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            try validateResponse(response)

            print("✅ Updated user preferences successfully")

        } catch let error as LambdaError {
            handleLambdaError(error)
            throw error
        } catch {
            let lambdaError = LambdaError.networkError(error)
            handleLambdaError(lambdaError)
            throw lambdaError
        }
    }

    // MARK: - Request Validation
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LambdaError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Success
            break
        case 400:
            throw LambdaError.badRequest
        case 401:
            throw LambdaError.unauthorized
        case 403:
            throw LambdaError.forbidden
        case 429:
            isRateLimited = true
            throw LambdaError.rateLimitExceeded
        case 500...599:
            throw LambdaError.serverError(httpResponse.statusCode)
        default:
            throw LambdaError.unknownError(httpResponse.statusCode)
        }
    }

    // MARK: - Error Handling
    private func handleLambdaError(_ error: LambdaError) {
        errorMessage = error.localizedDescription

        switch error {
        case .rateLimitExceeded:
            isRateLimited = true
        case .unauthorized:
            // Could trigger re-authentication flow
            break
        default:
            break
        }

        print("❌ Lambda service error: \(error.localizedDescription)")
    }

    // MARK: - Retry Logic
    func executeWithRetry<T>(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch LambdaError.rateLimitExceeded {
                // Don't retry rate limit errors
                throw lastError ?? LambdaError.rateLimitExceeded
            } catch {
                lastError = error

                if attempt == maxRetries {
                    break
                }

                let delay = initialDelay * Double(attempt)
                print("⚠️ Request failed (attempt \(attempt)/\(maxRetries)), retrying in \(delay)s...")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? LambdaError.unknownError(0)
    }

    // MARK: - Rate Limiting Helpers
    func checkRateLimit() -> (canMakeRequest: Bool, resetTime: Date?) {
        if dailyUsage >= dailyLimit {
            // Calculate reset time (midnight UTC)
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let resetTime = calendar.startOfDay(for: tomorrow)

            return (false, resetTime)
        }

        return (true, nil)
    }

    func resetRateLimit() {
        dailyUsage = 0
        isRateLimited = false
        print("🔄 Rate limit reset")
    }
}

// MARK: - Request/Response Models
struct QuestionGenerationRequest: Codable {
    let position: String
    let company: String
    let yearsOfExperience: String
    let difficulty: String
    let questionType: String
}

struct QuestionGenerationResponse: Codable {
    let questions: [GeneratedQuestion]
    let metadata: QuestionMetadata?
}

struct GeneratedQuestion: Codable, Identifiable {
    let id: Int
    let question: String
    let type: String
    let category: String
    let difficulty: String
    let followUpTips: String?
}

struct QuestionMetadata: Codable {
    let position: String
    let company: String
    let yearsOfExperience: String
    let difficulty: String
    let questionType: String
    let generatedAt: String
    let dailyUsage: Int
    let dailyLimit: Int
}

struct UserProfile: Codable {
    let username: String
    let email: String
    let subscriptionTier: String
    let dailyUsage: Int
    let dailyLimit: Int
    let monthlyQuota: Int
    let preferences: UserPreferences?
}

struct UserPreferences: Codable {
    let voiceId: String?
    let speechRate: Double?
    let autoSubmit: Bool?
    let notificationsEnabled: Bool?
    let dailyQuestionsEnabled: Bool?
    let preferredDifficulty: String?
    let theme: String?
}

// MARK: - Error Types
enum LambdaError: LocalizedError {
    case invalidURL(String)
    case authenticationRequired
    case encodingError(Error)
    case networkError(Error)
    case invalidResponse
    case badRequest
    case unauthorized
    case forbidden
    case rateLimitExceeded
    case serverError(Int)
    case unknownError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .authenticationRequired:
            return "Authentication required. Please sign in."
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .badRequest:
            return "Invalid request parameters"
        case .unauthorized:
            return "Authentication failed. Please sign in again."
        case .forbidden:
            return "Access denied. Please check your permissions."
        case .rateLimitExceeded:
            return "Daily question limit exceeded. Upgrade to premium for more questions."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .unknownError(let code):
            return "Unexpected error (\(code)). Please try again."
        }
    }
}

// MARK: - Mock Data for Testing
extension LambdaService {
    func generateMockQuestions(
        position: String,
        company: String
    ) -> QuestionGenerationResponse {
        let mockQuestions = [
            GeneratedQuestion(
                id: 1,
                question: "Tell me about your experience with \(position) roles and why you're interested in working at \(company).",
                type: "behavioral",
                category: "General",
                difficulty: "medium",
                followUpTips: "Focus on specific examples and connect your experience to the company's mission."
            ),
            GeneratedQuestion(
                id: 2,
                question: "Describe a challenging project you worked on and how you overcame obstacles.",
                type: "behavioral",
                category: "Problem Solving",
                difficulty: "medium",
                followUpTips: "Use the STAR method: Situation, Task, Action, Result."
            ),
            GeneratedQuestion(
                id: 3,
                question: "How do you stay current with industry trends and technologies?",
                type: "behavioral",
                category: "Learning",
                difficulty: "easy",
                followUpTips: "Mention specific resources, communities, or practices you follow."
            )
        ]

        let metadata = QuestionMetadata(
            position: position,
            company: company,
            yearsOfExperience: "entry-level",
            difficulty: "medium",
            questionType: "behavioral",
            generatedAt: Date().ISO8601Format(),
            dailyUsage: dailyUsage + 1,
            dailyLimit: dailyLimit
        )

        return QuestionGenerationResponse(questions: mockQuestions, metadata: metadata)
    }
}