import Foundation

struct Question: Codable, Identifiable, Equatable, Hashable {
    let questionId: Int
    let text: String
    let order: Int
    let omitted: Bool
    let skipped: Bool?
    let parentQuestionId: Int?
    let isFollowUp: Bool
    let createdAt: String?
    
    var id: Int { questionId }
    
    // Computed property for backwards compatibility
    var isSkipped: Bool {
        skipped ?? false
    }
    
    init(questionId: Int, text: String, order: Int, omitted: Bool, skipped: Bool = false, parentQuestionId: Int? = nil, isFollowUp: Bool = false, createdAt: String? = nil) {
        self.questionId = questionId
        self.text = text
        self.order = order
        self.omitted = omitted
        self.skipped = skipped
        self.parentQuestionId = parentQuestionId
        self.isFollowUp = isFollowUp
        self.createdAt = createdAt
    }
}