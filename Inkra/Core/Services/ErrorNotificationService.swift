import Foundation

/// Service for posting server error notifications that loading views can react to
class ErrorNotificationService {
    static let shared = ErrorNotificationService()
    
    private init() {}
    
    /// Post a server error notification that loading views can listen to
    func postServerError(statusCode: Int, message: String? = nil) {
        let userInfo: [String: Any] = [
            "statusCode": statusCode,
            "message": message ?? ""
        ]
        
        NotificationCenter.default.post(
            name: .init("ServerError"), 
            object: nil, 
            userInfo: userInfo
        )
    }
    
    /// Post a network error notification
    func postNetworkError(message: String) {
        let userInfo: [String: Any] = [
            "statusCode": 0, // Use 0 for network errors
            "message": message
        ]
        
        NotificationCenter.default.post(
            name: .init("ServerError"), 
            object: nil, 
            userInfo: userInfo
        )
    }
}

// Example usage in network service methods:
/*
// In your HTTP response handling code:
if let httpResponse = response as? HTTPURLResponse {
    if httpResponse.statusCode >= 400 {
        ErrorNotificationService.shared.postServerError(
            statusCode: httpResponse.statusCode,
            message: "Request failed with status \(httpResponse.statusCode)"
        )
    }
}

// For network connectivity issues:
if error != nil {
    ErrorNotificationService.shared.postNetworkError(
        message: "Unable to connect to the server. Please check your internet connection."
    )
}
*/