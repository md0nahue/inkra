import Foundation

struct IdentifiableURL: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
}