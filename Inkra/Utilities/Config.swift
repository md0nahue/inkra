import Foundation

/// Application configuration based on build configuration
@available(iOS 15.0, macOS 12.0, *)
struct Config {
    /// Base URL for API endpoints
    static var baseURL: String {
        // First, check if we have an API_BASE_URL from Info.plist (set via xcconfig)
        if let infoPlistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !infoPlistURL.isEmpty {
            return infoPlistURL
        }
        
        // Then check environment variable (useful for CI/CD and testing)
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !envURL.isEmpty {
            return envURL
        }
        
        // Fall back to compile-time flags
        #if DEBUG
        return "http://localhost:3000"
        #elseif STAGING
        return "https://staging-api.inkra.com"  // Placeholder staging URL
        #else
        return "https://api.inkra.com"
        #endif
    }
    
    /// Environment name for debugging
    static var environment: String {
        // First, check if we have an ENVIRONMENT_NAME from Info.plist
        if let infoPlistEnv = Bundle.main.object(forInfoDictionaryKey: "ENVIRONMENT_NAME") as? String,
           !infoPlistEnv.isEmpty {
            return infoPlistEnv
        }
        
        // Then check environment variable
        if let envName = ProcessInfo.processInfo.environment["ENVIRONMENT_NAME"],
           !envName.isEmpty {
            return envName
        }
        
        // Fall back to compile-time flags
        #if DEBUG
        return "Development"
        #elseif STAGING
        return "Staging"
        #else
        return "Production"
        #endif
    }
    
    /// Check if we're running in staging environment
    static var isStaging: Bool {
        #if STAGING
        return true
        #else
        return environment.lowercased() == "staging"
        #endif
    }
    
    /// Check if we're running in production environment
    static var isProduction: Bool {
        #if RELEASE
        return true
        #else
        return environment.lowercased() == "production"
        #endif
    }
    
    /// Check if we're running in development/debug environment
    static var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return environment.lowercased() == "development"
        #endif
    }
}