import Foundation
import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
@MainActor
public class AppStateService: ObservableObject {
    @Published var showSessionExpiredToast: Bool = false
    @Published var sessionExpiredMessage: String = ""
    
    public static let shared = AppStateService()
    
    private init() {}
    
    func showSessionExpiredMessage(_ message: String = "Your session has expired. Please log in again.") {
        sessionExpiredMessage = message
        showSessionExpiredToast = true
    }
}