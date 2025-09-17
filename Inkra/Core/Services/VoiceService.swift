import Foundation

@MainActor
class VoiceService: ObservableObject {
    @Published var cachedVoices: [PollyVoice] = []
    
    static let shared = VoiceService()
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.networkService = networkService
    }
    
    func fetchAndCacheVoices() async {
        do {
            let endpoint = PollyVoicesEndpoint.getPollyVoices(language: nil)
            let response = try await networkService.request(endpoint, responseType: PollyVoicesResponse.self)
            
            await MainActor.run {
                self.cachedVoices = response.voices
            }
            
            // Store in UserDefaults for offline access
            if let encoded = try? JSONEncoder().encode(self.cachedVoices) {
                UserDefaults.standard.set(encoded, forKey: "cachedPollyVoices")
            }
        } catch {
            print("Failed to fetch Polly voices: \(error)")
            // Try to load from cache first
            if let data = UserDefaults.standard.data(forKey: "cachedPollyVoices"),
               let voices = try? JSONDecoder().decode([PollyVoice].self, from: data) {
                await MainActor.run {
                    self.cachedVoices = voices
                }
                return
            }
            
            // If no cache available, use fallback voices from PollyVoiceList
            await MainActor.run {
                self.cachedVoices = PollyVoiceList.englishVoices
            }
        }
    }
    
    func getVoiceUrl(for voiceId: String) -> String? {
        return cachedVoices.first { $0.id == voiceId }?.demoUrl
    }
}