import Foundation
import CoreData

extension ProjectEntity {
    var projectStatus: Project.ProjectStatus {
        get {
            Project.ProjectStatus(rawValue: status ?? "") ?? .outlineGenerating
        }
        set {
            status = newValue.rawValue
        }
    }
    
    func toProject() -> Project {
        return Project(
            id: Int(id),
            title: title ?? "",
            createdAt: createdAt ?? Date(),
            lastModifiedAt: lastModifiedAt ?? Date(),
            lastAccessedAt: nil,
            preset: nil,
            outline: outline?.toOutline(),
            isSpeechInterview: isSpeechInterview,
            presetId: presetId > 0 ? Int(presetId) : nil,
            isOffline: nil
        )
    }
    
    func updateFrom(project: Project) {
        self.id = Int32(project.id)
        self.title = project.title
        self.status = project.status.rawValue
        self.createdAt = project.createdAt
        self.lastModifiedAt = project.lastModifiedAt
        self.lastSyncedAt = Date()
        self.isSpeechInterview = project.isSpeechInterview ?? false
        if let presetId = project.presetId {
            self.presetId = Int32(presetId)
        }
    }
    
    static func create(from project: Project, in context: NSManagedObjectContext) -> ProjectEntity {
        let entity = ProjectEntity(context: context)
        entity.updateFrom(project: project)
        return entity
    }
}