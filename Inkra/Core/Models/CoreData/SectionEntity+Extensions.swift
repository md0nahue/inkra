import Foundation
import CoreData

extension SectionEntity {
    func toSection() -> Section {
        let questionsArray = (questions?.allObjects as? [QuestionEntity])?.sorted(by: { $0.order < $1.order }) ?? []
        return Section(
            sectionId: Int(id),
            title: title ?? "",
            order: Int(order),
            omitted: omitted,
            questions: questionsArray.map { $0.toQuestion() }
        )
    }
    
    func updateFrom(section: Section, in context: NSManagedObjectContext) {
        self.id = Int32(section.sectionId)
        self.title = section.title
        self.order = Int32(section.order)
        self.omitted = section.omitted
        
        // Update questions
        if let existingQuestions = questions?.allObjects as? [QuestionEntity] {
            for question in existingQuestions {
                context.delete(question)
            }
        }
        
        let newQuestions = NSSet(array: section.questions.map { question in
            let questionEntity = QuestionEntity.create(from: question, in: context)
            questionEntity.section = self
            return questionEntity
        })
        self.questions = newQuestions
    }
    
    static func create(from section: Section, in context: NSManagedObjectContext) -> SectionEntity {
        let entity = SectionEntity(context: context)
        entity.updateFrom(section: section, in: context)
        return entity
    }
}