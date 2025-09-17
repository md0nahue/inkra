import Foundation

struct Section: Codable, Identifiable, Equatable, Hashable {
    let sectionId: Int
    let title: String
    let order: Int
    var omitted: Bool
    var questions: [Question]
    
    var id: Int { sectionId }

    // No CodingKeys enum needed
}