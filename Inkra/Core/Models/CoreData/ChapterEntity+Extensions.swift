import Foundation
import CoreData

extension ChapterEntity {
    func toChapter() -> Chapter {
        let sectionsArray = (sections?.allObjects as? [SectionEntity])?.sorted(by: { $0.order < $1.order }) ?? []
        return Chapter(
            chapterId: Int(id),
            title: title ?? "",
            order: Int(order),
            omitted: omitted,
            sections: sectionsArray.map { $0.toSection() }
        )
    }
    
    func updateFrom(chapter: Chapter, in context: NSManagedObjectContext) {
        self.id = Int32(chapter.chapterId)
        self.title = chapter.title
        self.order = Int32(chapter.order)
        self.omitted = chapter.omitted
        
        // Update sections
        if let existingSections = sections?.allObjects as? [SectionEntity] {
            for section in existingSections {
                context.delete(section)
            }
        }
        
        let newSections = NSSet(array: chapter.sections.map { section in
            let sectionEntity = SectionEntity.create(from: section, in: context)
            sectionEntity.chapter = self
            return sectionEntity
        })
        self.sections = newSections
    }
    
    static func create(from chapter: Chapter, in context: NSManagedObjectContext) -> ChapterEntity {
        let entity = ChapterEntity(context: context)
        entity.updateFrom(chapter: chapter, in: context)
        return entity
    }
}