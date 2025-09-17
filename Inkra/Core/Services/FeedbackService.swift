import Foundation

enum FeedbackEndpoint: APIEndpoint {
    case create(CreateFeedbackRequest)
    case list
    
    var path: String {
        switch self {
        case .create, .list:
            return "/api/feedbacks"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .create:
            return .POST
        case .list:
            return .GET
        }
    }
    
    var body: Codable? {
        switch self {
        case .create(let request):
            return request
        case .list:
            return nil
        }
    }
}

class FeedbackService: ObservableObject {
    static let shared = FeedbackService()
    private let networkService = NetworkService.shared
    
    private init() {}
    
    func submitFeedback(text: String, type: FeedbackType, email: String?) async throws -> FeedbackResponse {
        let request = CreateFeedbackRequest(
            feedbackText: text,
            feedbackType: type.rawValue,
            email: email?.isEmpty == true ? nil : email
        )
        
        let endpoint = FeedbackEndpoint.create(request)
        return try await networkService.request(endpoint, responseType: FeedbackResponse.self)
    }
    
    func getFeedbackHistory() async throws -> FeedbackListResponse {
        let endpoint = FeedbackEndpoint.list
        return try await networkService.request(endpoint, responseType: FeedbackListResponse.self)
    }
}

enum FeedbackType: String, CaseIterable, Identifiable {
    case general = "general"
    case bugReport = "bug_report"
    case featureRequest = "feature_request"
    case improvement = "improvement"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .general:
            return "General Feedback"
        case .bugReport:
            return "Bug Report"
        case .featureRequest:
            return "Feature Request"
        case .improvement:
            return "Improvement Suggestion"
        }
    }
    
    var icon: String {
        switch self {
        case .general:
            return "bubble.left.and.bubble.right"
        case .bugReport:
            return "ladybug"
        case .featureRequest:
            return "lightbulb"
        case .improvement:
            return "arrow.up.circle"
        }
    }
    
    var color: ColorTheme {
        return ColorTheme()
    }
}