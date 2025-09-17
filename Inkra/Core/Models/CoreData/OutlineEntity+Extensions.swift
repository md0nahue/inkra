import Foundation
import CoreData

extension OutlineEntity {
    var outlineStatus: Outline.OutlineStatus {
        get {
            Outline.OutlineStatus(rawValue: status ?? "") ?? .generating
        }
        set {
            status = newValue.rawValue
        }
    }
    
    func toOutline() -> Outline {
        let chaptersArray = (chapters?.allObjects as? [ChapterEntity])?.sorted(by: { $0.order < $1.order }) ?? []
        return Outline(
            status: outlineStatus,
            chapters: chaptersArray.map { $0.toChapter() }
        )
    }
    
    func updateFrom(outline: Outline, in context: NSManagedObjectContext) {
        self.status = outline.status.rawValue
        
        // Update chapters
        if let existingChapters = chapters?.allObjects as? [ChapterEntity] {
            for chapter in existingChapters {
                context.delete(chapter)
            }
        }
        
        let newChapters = NSSet(array: outline.chapters.map { chapter in
            let chapterEntity = ChapterEntity.create(from: chapter, in: context)
            chapterEntity.outline = self
            return chapterEntity
        })
        self.chapters = newChapters
    }
    
    static func create(from outline: Outline, in context: NSManagedObjectContext) -> OutlineEntity {
        let entity = OutlineEntity(context: context)
        entity.updateFrom(outline: outline, in: context)
        return entity
    }
}