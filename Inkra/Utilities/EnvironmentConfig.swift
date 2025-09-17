import Foundation

/// Environment configuration loader for runtime API URL configuration
@available(iOS 15.0, macOS 12.0, *)
struct EnvironmentConfig {
    
    /// Load API base URL from environment with priority order:
    /// 1. ngrok configuration file (highest priority for staging builds)
    /// 2. Runtime environment variable
    /// 3. Info.plist configuration (from xcconfig)
    /// 4. Compile-time defaults (fallback)
    static func loadAPIBaseURL() -> String {
        // Priority 1: Check for ngrok configuration file (staging builds)
        if let ngrokURL = loadNgrokURL() {
            print("🌐 Using API_BASE_URL from ngrok tunnel: \(ngrokURL)")
            return ngrokURL
        }
        
        // Priority 2: Check runtime environment variable
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !envURL.isEmpty {
            print("📍 Using API_BASE_URL from environment: \(envURL)")
            return envURL
        }
        
        // Priority 3: Check Info.plist (set via xcconfig)
        if let infoPlistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !infoPlistURL.isEmpty {
            print("📍 Using API_BASE_URL from Info.plist: \(infoPlistURL)")
            return infoPlistURL
        }
        
        // Priority 4: Use Config.swift defaults
        let defaultURL = Config.baseURL
        print("📍 Using default API_BASE_URL: \(defaultURL)")
        return defaultURL
    }
    
    /// Load ngrok URL from configuration file if it exists
    private static func loadNgrokURL() -> String? {
        #if DEBUG
        let ngrokConfigPath = "/Users/magnusfremont/Desktop/VibeWriter/ngrok_config.json"
        
        guard FileManager.default.fileExists(atPath: ngrokConfigPath) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: ngrokConfigPath))
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let apiURL = json["api_base_url"] as? String {
                
                // Check if the config is recent (within last hour)
                if let timestamp = json["timestamp"] as? String {
                    let formatter = ISO8601DateFormatter()
                    if let date = formatter.date(from: timestamp) {
                        let age = Date().timeIntervalSince(date)
                        if age > 3600 { // More than 1 hour old
                            print("⚠️ ngrok config is \(Int(age/60)) minutes old, might be stale")
                        }
                    }
                }
                
                return apiURL
            }
        } catch {
            print("❌ Failed to load ngrok config: \(error)")
        }
        #endif
        return nil
    }
    
    /// Override API URL at runtime (useful for testing)
    /// - Parameter url: The new API base URL
    static func overrideAPIBaseURL(_ url: String) {
        // Store in UserDefaults for persistence across app launches
        UserDefaults.standard.set(url, forKey: "OverriddenAPIBaseURL")
        UserDefaults.standard.synchronize()
        print("✅ API_BASE_URL overridden to: \(url)")
    }
    
    /// Get the current effective API base URL
    static var currentAPIBaseURL: String {
        // Check for UserDefaults override first
        if let overriddenURL = UserDefaults.standard.string(forKey: "OverriddenAPIBaseURL"),
           !overriddenURL.isEmpty {
            return overriddenURL
        }
        return loadAPIBaseURL()
    }
    
    /// Clear any runtime URL override
    static func clearAPIBaseURLOverride() {
        UserDefaults.standard.removeObject(forKey: "OverriddenAPIBaseURL")
        UserDefaults.standard.synchronize()
        print("✅ API_BASE_URL override cleared")
    }
    
    /// Check if we're using a staging API
    static var isUsingStagingAPI: Bool {
        let url = currentAPIBaseURL.lowercased()
        return url.contains("staging") || url.contains("stage")
    }
    
    /// Check if we're using localhost
    static var isUsingLocalhost: Bool {
        let url = currentAPIBaseURL.lowercased()
        return url.contains("localhost") || url.contains("127.0.0.1")
    }
    
    /// Check if we're using ngrok tunnel
    static var isUsingNgrok: Bool {
        let url = currentAPIBaseURL.lowercased()
        return url.contains("ngrok") || url.contains(".ngrok-free.app") || url.contains(".ngrok.io")
    }
    
    /// Get ngrok tunnel status information
    static var ngrokStatus: String {
        guard isUsingNgrok else {
            return "Not using ngrok"
        }
        
        #if DEBUG
        let ngrokConfigPath = "/Users/magnusfremont/Desktop/VibeWriter/ngrok_config.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: ngrokConfigPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let timestamp = json["timestamp"] as? String,
               let pid = json["ngrok_pid"] as? Int {
                return "ngrok PID: \(pid), Started: \(timestamp)"
            }
        }
        #endif
        
        return "ngrok tunnel active"
    }
}