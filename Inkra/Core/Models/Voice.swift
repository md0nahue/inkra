import Foundation

// IMPORTANT: DO NOT add explicit CodingKeys to this struct!
// NetworkService has .convertFromSnakeCase globally configured.
// The backend sends: voice_id, demo_url which automatically map to voiceId, demoUrl
struct Voice: Codable, Identifiable {
    let voiceId: String
    let engine: String
    let demoUrl: String
    
    // Computed property for Identifiable conformance
    var id: String { voiceId }
    
    init(voiceId: String, engine: String, demoUrl: String) {
        self.voiceId = voiceId
        self.engine = engine
        self.demoUrl = demoUrl
    }
}

struct VoicesResponse: Codable {
    let voices: [Voice]
}