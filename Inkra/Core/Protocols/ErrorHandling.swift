import Foundation

/// Protocol for ViewModels that handle errors with published properties
@available(iOS 15.0, macOS 11.0, *)
@MainActor
protocol ErrorHandling: ObservableObject {
    var showError: Bool { get set }
    var errorMessage: String { get set }
}

/// Default error handling implementation
@available(iOS 15.0, macOS 11.0, *)
@MainActor
extension ErrorHandling {
    func handleError(_ error: Error) {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .networkUnavailable:
                errorMessage = "No internet connection. Please check your network and try again."
            case .serverError(let code):
                errorMessage = "Server error (\(code)). Please try again later."
            case .timeout:
                errorMessage = "Request timed out. Please try again."
            case .decodingError:
                errorMessage = "Invalid response from server. Please try again."
            case .invalidURL:
                errorMessage = "Invalid request. Please try again."
            case .unauthorized:
                // Auth disabled in V1 - handle as normal error
                errorMessage = "Unauthorized access. Please try again."
            case .validationError(let message):
                errorMessage = message
            default:
                errorMessage = "Network error occurred. Please try again."
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        showError = true
    }
}