import Foundation
import CoreData
import Combine

@MainActor
class DataManager: ObservableObject {
    nonisolated static let shared = DataManager()
    
    @Published var isInitialized = false
    
    nonisolated private init() {
        setupCoreData()
    }
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Inkra")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func backgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    nonisolated private func setupCoreData() {
        // Initialize the persistent container on the main actor
        Task { @MainActor in
            _ = persistentContainer
            isInitialized = true
        }
    }
    
    func save() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to save Core Data context: \(error)")
        }
    }
    
    func saveBackground(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        context.perform {
            do {
                try context.save()
            } catch {
                print("❌ Failed to save background Core Data context: \(error)")
            }
        }
    }
    
    // MARK: - Project Operations
    
    func fetchProjects() -> [Project] {
        print("🔍 DEBUG: === DataManager.fetchProjects() CALLED ===")
        
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ProjectEntity.lastModifiedAt, ascending: false)]
        
        do {
            print("🔍 DEBUG: Executing Core Data fetch request...")
            let projectEntities = try context.fetch(request)
            print("🔍 DEBUG: Core Data returned \(projectEntities.count) ProjectEntity objects")
            
            if projectEntities.isEmpty {
                print("🚨 DEBUG: CRITICAL - Core Data has NO ProjectEntity records")
                print("🔍 DEBUG: Context info: \(context)")
                print("🔍 DEBUG: Context has changes: \(context.hasChanges)")
                return []
            }
            
            // Debug each entity before conversion
            print("🔍 DEBUG: Raw ProjectEntity data:")
            for (index, entity) in projectEntities.enumerated() {
                print("   [\(index)] Entity ID: \(entity.id), Title: '\(entity.title ?? "nil")'")
                print("        Created: \(entity.createdAt?.description ?? "nil")")
                print("        Modified: \(entity.lastModifiedAt?.description ?? "nil")")
                print("        Has Outline: \(entity.outline != nil)")
                if let outline = entity.outline {
                    print("        Outline chapters: \(outline.chapters?.count ?? 0)")
                }
            }
            
            // Convert entities to Project objects
            print("🔍 DEBUG: Converting ProjectEntity objects to Project models...")
            let projects = projectEntities.enumerated().map { index, entity in
                print("   Converting entity [\(index)]: \(entity.title ?? "nil")")
                let project = entity.toProject()
                print("   Converted to: \(project.title) (\(project.outline?.chapters.count ?? 0) chapters)")
                return project
            }
            
            print("🔍 DEBUG: Successfully converted \(projectEntities.count) entities to \(projects.count) Project objects")
            
            // Final validation
            if projects.count != projectEntities.count {
                print("🚨 DEBUG: CONVERSION MISMATCH - Entities: \(projectEntities.count), Projects: \(projects.count)")
            }
            
            print("🔍 DEBUG: === DataManager.fetchProjects() RETURNING \(projects.count) projects ===")
            return projects
            
        } catch {
            print("❌ DEBUG: Core Data fetch failed: \(error)")
            print("🚨 DEBUG: Error details: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchProject(id: Int) -> Project? {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", id)
        request.fetchLimit = 1
        
        do {
            let projectEntities = try context.fetch(request)
            return projectEntities.first?.toProject()
        } catch {
            print("❌ Failed to fetch project \(id): \(error)")
            return nil
        }
    }
    
    func saveProject(_ project: Project) {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", project.id)
        request.fetchLimit = 1
        
        do {
            let existingEntities = try context.fetch(request)
            let projectEntity = existingEntities.first ?? ProjectEntity(context: context)
            
            projectEntity.updateFrom(project: project)
            
            // Handle outline if present
            if let outline = project.outline {
                if let existingOutline = projectEntity.outline {
                    existingOutline.updateFrom(outline: outline, in: context)
                } else {
                    let outlineEntity = OutlineEntity.create(from: outline, in: context)
                    projectEntity.outline = outlineEntity
                    outlineEntity.project = projectEntity
                }
            }
            
            save()
        } catch {
            print("❌ Failed to save project: \(error)")
        }
    }
    
    func deleteProject(id: Int) {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", id)
        
        do {
            let projectEntities = try context.fetch(request)
            for entity in projectEntities {
                context.delete(entity)
            }
            save()
        } catch {
            print("❌ Failed to delete project \(id): \(error)")
        }
    }
    
    func clearProject(id: Int) {
        print("🗑️ Clearing stale local data for project \(id)")
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", id)
        
        do {
            let projectEntities = try context.fetch(request)
            for entity in projectEntities {
                context.delete(entity)
            }
            save()
            print("✅ Cleared local data for project \(id)")
        } catch {
            print("❌ Failed to clear project \(id): \(error)")
        }
    }
    
    // MARK: - Question Operations
    
    func saveQuestion(_ question: Question, to sectionId: Int) {
        let sectionRequest: NSFetchRequest<SectionEntity> = SectionEntity.fetchRequest()
        sectionRequest.predicate = NSPredicate(format: "id == %d", sectionId)
        sectionRequest.fetchLimit = 1
        
        do {
            let sectionEntities = try context.fetch(sectionRequest)
            guard let sectionEntity = sectionEntities.first else {
                print("❌ Section \(sectionId) not found for question")
                return
            }
            
            // Check if question already exists
            let questionRequest: NSFetchRequest<QuestionEntity> = QuestionEntity.fetchRequest()
            questionRequest.predicate = NSPredicate(format: "id == %d", question.id)
            questionRequest.fetchLimit = 1
            
            let existingQuestions = try context.fetch(questionRequest)
            let questionEntity = existingQuestions.first ?? QuestionEntity(context: context)
            
            questionEntity.updateFrom(question: question)
            questionEntity.section = sectionEntity
            
            save()
        } catch {
            print("❌ Failed to save question: \(error)")
        }
    }
    
    func addQuestions(_ questions: [Question], to projectId: Int) {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", projectId)
        request.fetchLimit = 1

        do {
            guard try context.fetch(request).first != nil else {
                print("❌ Project \(projectId) not found in DataManager to add questions.")
                return
            }

            for question in questions {
                guard let parentId = question.parentQuestionId else { continue }

                // Find the section that contains the parent question.
                // This is a bit complex due to the data model, but it's robust.
                let parentQuestionRequest: NSFetchRequest<QuestionEntity> = QuestionEntity.fetchRequest()
                parentQuestionRequest.predicate = NSPredicate(format: "id == %d", parentId)
                parentQuestionRequest.fetchLimit = 1

                if let parentEntity = try context.fetch(parentQuestionRequest).first,
                   let sectionEntity = parentEntity.section {

                    // Create and link the new question
                    let newQuestionEntity = QuestionEntity.create(from: question, in: context)
                    sectionEntity.addToQuestions(newQuestionEntity)
                }
            }

            save()
            print("✅ DataManager saved \(questions.count) new questions to project \(projectId).")
        } catch {
            print("❌ Failed to add questions to project \(projectId): \(error)")
        }
    }
    
    // MARK: - Audio Segment Operations
    
    func saveAudioSegment(_ audioSegment: AudioSegment) {
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", audioSegment.id)
        request.fetchLimit = 1
        
        do {
            let existingEntities = try context.fetch(request)
            let audioEntity = existingEntities.first ?? AudioSegmentEntity(context: context)
            
            audioEntity.updateFrom(audioSegment: audioSegment)
            
            // Link to question if available
            if let questionId = audioSegment.questionId {
                let questionRequest: NSFetchRequest<QuestionEntity> = QuestionEntity.fetchRequest()
                questionRequest.predicate = NSPredicate(format: "id == %d", questionId)
                questionRequest.fetchLimit = 1
                
                let questionEntities = try context.fetch(questionRequest)
                audioEntity.question = questionEntities.first
            }
            
            save()
        } catch {
            print("❌ Failed to save audio segment: \(error)")
        }
    }
    
    func saveAudioSegmentLocalInfo(questionId: Int, projectId: Int, localFileURL: URL, isUploaded: Bool, audioSegmentId: Int? = nil) {
        // First find audio segment by question and project
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "question.id == %d AND question.section.chapter.outline.project.id == %d", questionId, projectId)
        request.fetchLimit = 1
        
        do {
            let existingEntities = try context.fetch(request)
            
            if let audioEntity = existingEntities.first {
                // Update existing entity
                audioEntity.updateLocalFileInfo(localFileURL: localFileURL, isUploaded: isUploaded)
                if let audioSegmentId = audioSegmentId {
                    audioEntity.id = Int32(audioSegmentId)
                }
            } else {
                // Create new entity
                let audioEntity = AudioSegmentEntity(context: context)
                audioEntity.id = Int32(audioSegmentId ?? 0)
                audioEntity.updateLocalFileInfo(localFileURL: localFileURL, isUploaded: isUploaded)
                
                // Link to question
                let questionRequest: NSFetchRequest<QuestionEntity> = QuestionEntity.fetchRequest()
                questionRequest.predicate = NSPredicate(format: "id == %d", questionId)
                questionRequest.fetchLimit = 1
                
                let questionEntities = try context.fetch(questionRequest)
                audioEntity.question = questionEntities.first
            }
            
            save()
        } catch {
            print("❌ Failed to save audio segment local info: \(error)")
        }
    }
    
    func fetchAudioSegmentsWithLocalFiles(for projectId: Int) -> [(questionId: Int, localFileURL: URL, isUploaded: Bool, audioSegmentId: Int?)] {
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "question.section.chapter.outline.project.id == %d AND localFileURL != nil", projectId)
        
        do {
            let audioEntities = try context.fetch(request)
            return audioEntities.compactMap { entity in
                guard let questionId = entity.question?.id,
                      let urlString = entity.localFileURL,
                      let url = URL(string: urlString) else { return nil }
                
                return (
                    questionId: Int(questionId),
                    localFileURL: url,
                    isUploaded: entity.isUploaded,
                    audioSegmentId: entity.id != 0 ? Int(entity.id) : nil
                )
            }
        } catch {
            print("❌ Failed to fetch audio segments with local files: \(error)")
            return []
        }
    }
    
    func deleteAudioSegmentLocalInfo(questionId: Int, projectId: Int) {
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "question.id == %d AND question.section.chapter.outline.project.id == %d", questionId, projectId)
        request.fetchLimit = 1
        
        do {
            let existingEntities = try context.fetch(request)
            if let audioEntity = existingEntities.first {
                audioEntity.localFileURL = nil
                audioEntity.isUploaded = false
                save()
            }
        } catch {
            print("❌ Failed to delete audio segment local info: \(error)")
        }
    }
    
    // MARK: - Transcript Operations
    
    func saveTranscript(_ transcript: Transcript) {
        let request: NSFetchRequest<TranscriptEntity> = TranscriptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", transcript.id)
        request.fetchLimit = 1
        
        do {
            let existingEntities = try context.fetch(request)
            let transcriptEntity = existingEntities.first ?? TranscriptEntity(context: context)
            
            transcriptEntity.updateFrom(transcript: transcript, in: context)
            
            // Link to project
            let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            projectRequest.predicate = NSPredicate(format: "id == %d", transcript.projectId)
            projectRequest.fetchLimit = 1
            
            let projectEntities = try context.fetch(projectRequest)
            transcriptEntity.project = projectEntities.first
            
            save()
        } catch {
            print("❌ Failed to save transcript: \(error)")
        }
    }
    
    func fetchTranscripts(for projectId: Int) -> [Transcript] {
        let request: NSFetchRequest<TranscriptEntity> = TranscriptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "project.id == %d", projectId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TranscriptEntity.lastUpdated, ascending: false)]
        
        do {
            let transcriptEntities = try context.fetch(request)
            return transcriptEntities.map { $0.toTranscript() }
        } catch {
            print("❌ Failed to fetch transcripts for project \(projectId): \(error)")
            return []
        }
    }
    
    // MARK: - Sync Utilities
    
    func updateLastSyncedAt(for projectId: Int) {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", projectId)
        request.fetchLimit = 1
        
        do {
            let projectEntities = try context.fetch(request)
            if let projectEntity = projectEntities.first {
                projectEntity.lastSyncedAt = Date()
                save()
            }
        } catch {
            print("❌ Failed to update lastSyncedAt for project \(projectId): \(error)")
        }
    }
    
    func getStaleProjects(olderThan timeInterval: TimeInterval) -> [Project] {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "lastSyncedAt == nil OR lastSyncedAt < %@", cutoffDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ProjectEntity.lastModifiedAt, ascending: false)]
        
        do {
            let projectEntities = try context.fetch(request)
            return projectEntities.map { $0.toProject() }
        } catch {
            print("❌ Failed to fetch stale projects: \(error)")
            return []
        }
    }
    
    // MARK: - Bulk Operations
    
    func saveProjects(_ projects: [Project]) {
        print("🔍 DEBUG: === DataManager.saveProjects() CALLED with \(projects.count) projects ===")
        
        if projects.isEmpty {
            print("⚠️ DEBUG: WARNING - Attempting to save EMPTY projects array")
            return
        }
        
        // Log what we're trying to save
        print("🔍 DEBUG: Projects to save:")
        for (index, project) in projects.enumerated() {
            print("   [\(index)] \(project.title) (ID: \(project.id))")
            print("        Has outline: \(project.outline != nil)")
            if let outline = project.outline {
                let questionCount = outline.chapters.flatMap { $0.sections }.flatMap { $0.questions }.count
                print("        Questions: \(questionCount)")
            }
        }
        
        let backgroundContext = backgroundContext()
        
        backgroundContext.perform {
            print("🔍 DEBUG: Background context performing bulk save...")
            
            var savedCount = 0
            var errorCount = 0
            
            for project in projects {
                let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %d", project.id)
                request.fetchLimit = 1
                
                do {
                    let existingEntities = try backgroundContext.fetch(request)
                    let isNewProject = existingEntities.isEmpty
                    let projectEntity = existingEntities.first ?? ProjectEntity(context: backgroundContext)
                    
                    print("🔍 DEBUG: \(isNewProject ? "Creating new" : "Updating existing") ProjectEntity for \(project.title)")
                    
                    projectEntity.updateFrom(project: project)
                    
                    // Handle outline if present
                    if let outline = project.outline {
                        print("🔍 DEBUG: Saving outline with \(outline.chapters.count) chapters")
                        if let existingOutline = projectEntity.outline {
                            existingOutline.updateFrom(outline: outline, in: backgroundContext)
                        } else {
                            let outlineEntity = OutlineEntity.create(from: outline, in: backgroundContext)
                            projectEntity.outline = outlineEntity
                            outlineEntity.project = projectEntity
                        }
                    } else {
                        print("⚠️ DEBUG: Project \(project.title) has no outline to save")
                    }
                    
                    savedCount += 1
                    
                } catch {
                    errorCount += 1
                    print("❌ DEBUG: Failed to save project \(project.id) in bulk: \(error)")
                    print("🚨 DEBUG: Error details: \(error.localizedDescription)")
                }
            }
            
            print("🔍 DEBUG: Bulk save summary - Saved: \(savedCount), Errors: \(errorCount)")
            
            print("🔍 DEBUG: Calling saveBackground()...")
            self.saveBackground(backgroundContext)
            print("🔍 DEBUG: saveBackground() completed")
            
            print("🔍 DEBUG: === DataManager.saveProjects() COMPLETED ===")
        }
    }
    
    // MARK: - Data Reset
    
    func clearAllData() {
        let entityNames = ["ProjectEntity", "OutlineEntity", "ChapterEntity", "SectionEntity", "QuestionEntity", "AudioSegmentEntity", "TranscriptEntity", "TranscriptContentEntity"]
        
        for entityName in entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("❌ Failed to clear \(entityName): \(error)")
            }
        }
        
        save()
    }
}