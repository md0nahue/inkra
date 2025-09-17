import Foundation

protocol VibeLogAPI {
    func uploadTracker(data: Data) async throws -> String
}

class DefaultVibeLogAPI: VibeLogAPI {
    func uploadTracker(data: Data) async throws -> String {
        // Placeholder implementation
        throw NSError(domain: "VibeLogAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "VibeLog API not implemented"])
    }
}