import Foundation

@available(iOS 15.0, macOS 12.0, *)
struct AppConfig {
    static var apiBaseURL: String {
        // Use the unified EnvironmentConfig for API URL
        return EnvironmentConfig.currentAPIBaseURL
    }
    
    static var environment: String {
        // Use the unified Config for environment name
        return Config.environment
    }
    
    static var shouldUploadLogs: Bool {
        // Only upload logs in staging builds
        return Config.isStaging
    }
    
    static var shouldShowDiagnostics: Bool {
        // Show diagnostics in debug and staging builds
        return Config.isDevelopment || Config.isStaging
    }
}