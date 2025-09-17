import Foundation

struct Chapter: Codable, Identifiable, Equatable, Hashable {
    let chapterId: Int
    let title: String
    let order: Int
    var omitted: Bool
    var sections: [Section]
    
    var id: Int { chapterId }

    // No CodingKeys enum needed thanks to .convertFromSnakeCase
}