import Foundation

struct PollyVoice: Codable, Identifiable {
    let id: String
    let name: String
    let gender: String
    let neural: Bool
    let languageCode: String
    let demoUrl: String?
}

struct PollyVoicesResponse: Codable {
    let voices: [PollyVoice]
    let defaultVoiceId: String
    let supportedSpeechRates: [Int]
}

enum PollyVoicesEndpoint: APIEndpoint {
    case getPollyVoices(language: String?)
    
    var path: String {
        switch self {
        case .getPollyVoices(let language):
            var path = "/api/polly_voices"
            if let language = language {
                path += "?language=\(language)"
            }
            return path
        }
    }
    
    var method: HTTPMethod {
        return .GET
    }
    
    var body: Codable? {
        return nil
    }
}