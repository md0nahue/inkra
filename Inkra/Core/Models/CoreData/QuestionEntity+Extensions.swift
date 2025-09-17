import Foundation
import CoreData

extension QuestionEntity {
    func toQuestion() -> Question {
        return Question(
            questionId: Int(id),
            text: text ?? "",
            order: Int(order),
            omitted: omitted,
            parentQuestionId: parentQuestionId == 0 ? nil : Int(parentQuestionId),
            isFollowUp: isFollowUp
        )
    }
    
    func updateFrom(question: Question) {
        self.id = Int32(question.questionId)
        self.text = question.text
        self.order = Int32(question.order)
        self.omitted = question.omitted
        self.parentQuestionId = Int32(question.parentQuestionId ?? 0)
        self.isFollowUp = question.isFollowUp
    }
    
    static func create(from question: Question, in context: NSManagedObjectContext) -> QuestionEntity {
        let entity = QuestionEntity(context: context)
        entity.updateFrom(question: question)
        return entity
    }
}