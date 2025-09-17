import Foundation
import CoreData

extension TranscriptEntity {
    var transcriptStatus: Transcript.TranscriptStatus {
        get {
            Transcript.TranscriptStatus(rawValue: status ?? "") ?? .processingRaw
        }
        set {
            status = newValue.rawValue
        }
    }
    
    func toTranscript() -> Transcript {
        let contentArray = (content?.allObjects as? [TranscriptContentEntity]) ?? []
        return Transcript(
            id: Int(id),
            projectId: project?.id != nil ? Int(project!.id) : 0,
            status: status != nil ? transcriptStatus : nil,
            lastUpdated: lastUpdated ?? Date(),
            rawContent: nil,
            polishedContent: nil,
            editedContent: contentArray.map { $0.toTranscriptContent() },
            rawStructuredContent: nil
        )
    }
    
    func updateFrom(transcript: Transcript, in context: NSManagedObjectContext) {
        self.id = Int32(transcript.id)
        self.status = transcript.status?.rawValue
        self.lastUpdated = transcript.lastUpdated ?? Date()
        
        // Update content
        if let existingContent = content?.allObjects as? [TranscriptContentEntity] {
            for contentItem in existingContent {
                context.delete(contentItem)
            }
        }
        
        let newContent = NSSet(array: transcript.editedContent.map { contentItem in
            let contentEntity = TranscriptContentEntity.create(from: contentItem, in: context)
            contentEntity.transcript = self
            return contentEntity
        })
        self.content = newContent
    }
    
    static func create(from transcript: Transcript, in context: NSManagedObjectContext) -> TranscriptEntity {
        let entity = TranscriptEntity(context: context)
        entity.updateFrom(transcript: transcript, in: context)
        return entity
    }
}

extension TranscriptContentEntity {
    var contentType: TranscriptContent.ContentType {
        get {
            TranscriptContent.ContentType(rawValue: type ?? "") ?? .paragraph
        }
        set {
            type = newValue.rawValue
        }
    }
    
    func toTranscriptContent() -> TranscriptContent {
        return TranscriptContent(
            type: contentType,
            chapterId: chapterId == 0 ? nil : Int(chapterId),
            sectionId: sectionId == 0 ? nil : Int(sectionId),
            questionId: questionId == 0 ? nil : Int(questionId),
            title: title,
            text: text,
            audioSegmentId: audioSegmentId == 0 ? nil : Int(audioSegmentId)
        )
    }
    
    func updateFrom(content: TranscriptContent) {
        self.type = content.type.rawValue
        self.chapterId = Int32(content.chapterId ?? 0)
        self.sectionId = Int32(content.sectionId ?? 0)
        self.questionId = Int32(content.questionId ?? 0)
        self.title = content.title
        self.text = content.text
        self.audioSegmentId = Int32(content.audioSegmentId ?? 0)
    }
    
    static func create(from content: TranscriptContent, in context: NSManagedObjectContext) -> TranscriptContentEntity {
        let entity = TranscriptContentEntity(context: context)
        entity.updateFrom(content: content)
        return entity
    }
}