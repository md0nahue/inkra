import Foundation
import CoreData

extension AudioSegmentEntity {

    // MARK: - Local-First Properties

    var localStorageStatus: LocalStorageStatus {
        get {
            LocalStorageStatus(rawValue: localStorageStatusRaw ?? "") ?? .notStored
        }
        set {
            localStorageStatusRaw = newValue.rawValue
        }
    }

    enum LocalStorageStatus: String, CaseIterable {
        case notStored = "not_stored"
        case stored = "stored"
        case pendingUpload = "pending_upload"
        case uploaded = "uploaded"
        case failed = "failed"
    }

    // MARK: - Simplified Audio Segment Conversion

    func toLocalAudioSegment() -> LocalAudioSegment {
        return LocalAudioSegment(
            id: id != 0 ? Int(id) : nil,
            questionId: question?.id != nil ? Int(question!.id) : nil,
            fileName: fileName ?? "",
            localFileURL: localFileURL != nil ? URL(string: localFileURL!) : nil,
            duration: recordedDurationSeconds,
            storageStatus: localStorageStatus,
            createdAt: createdAt ?? Date(),
            lastModifiedAt: lastModifiedAt ?? Date(),
            metadata: parseMetadata()
        )
    }

    func updateFromLocal(audioSegment: LocalAudioSegment) {
        if let segmentId = audioSegment.id {
            self.id = Int32(segmentId)
        }

        if let questionId = audioSegment.questionId {
            // Find and link to question
            let request: NSFetchRequest<QuestionEntity> = QuestionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %d", questionId)
            request.fetchLimit = 1

            if let context = self.managedObjectContext,
               let questionEntity = try? context.fetch(request).first {
                self.question = questionEntity
            }
        }

        self.fileName = audioSegment.fileName
        self.localFileURL = audioSegment.localFileURL?.absoluteString
        self.recordedDurationSeconds = audioSegment.duration
        self.localStorageStatus = audioSegment.storageStatus
        self.lastModifiedAt = Date()

        if let metadata = audioSegment.metadata {
            self.metadataJSON = try? JSONSerialization.data(with: metadata)
        }
    }

    static func createLocal(from audioSegment: LocalAudioSegment, in context: NSManagedObjectContext) -> AudioSegmentEntity {
        let entity = AudioSegmentEntity(context: context)
        entity.createdAt = Date()
        entity.updateFromLocal(audioSegment: audioSegment)
        return entity
    }

    // MARK: - Metadata Handling

    private func parseMetadata() -> [String: Any]? {
        guard let metadataJSON = metadataJSON else { return nil }
        return try? JSONSerialization.jsonObject(with: metadataJSON) as? [String: Any]
    }

    func updateMetadata(_ metadata: [String: Any]) {
        self.metadataJSON = try? JSONSerialization.data(withJSONObject: metadata)
        self.lastModifiedAt = Date()
    }

    // MARK: - Local File Management

    func markAsStored(at url: URL) {
        self.localFileURL = url.absoluteString
        self.localStorageStatus = .stored
        self.lastModifiedAt = Date()
    }

    func markAsPendingUpload() {
        self.localStorageStatus = .pendingUpload
        self.lastModifiedAt = Date()
    }

    func markAsUploaded(with serverId: Int) {
        self.id = Int32(serverId)
        self.localStorageStatus = .uploaded
        self.isUploaded = true
        self.lastModifiedAt = Date()
    }

    func markAsFailed(error: String? = nil) {
        self.localStorageStatus = .failed
        if let error = error {
            var metadata = parseMetadata() ?? [:]
            metadata["lastError"] = error
            updateMetadata(metadata)
        }
        self.lastModifiedAt = Date()
    }

    // MARK: - Cleanup Helpers

    func removeLocalFile() {
        if let urlString = localFileURL,
           let url = URL(string: urlString),
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        self.localFileURL = nil
        self.localStorageStatus = .notStored
        self.lastModifiedAt = Date()
    }
}

// MARK: - Local Audio Segment Model

struct LocalAudioSegment: Codable, Identifiable {
    let id: Int?
    let questionId: Int?
    let fileName: String
    let localFileURL: URL?
    let duration: TimeInterval
    let storageStatus: AudioSegmentEntity.LocalStorageStatus
    let createdAt: Date
    let lastModifiedAt: Date
    let metadata: [String: Any]?

    private enum CodingKeys: String, CodingKey {
        case id, questionId, fileName, localFileURL, duration, storageStatus, createdAt, lastModifiedAt
    }

    init(id: Int? = nil,
         questionId: Int? = nil,
         fileName: String,
         localFileURL: URL? = nil,
         duration: TimeInterval = 0,
         storageStatus: AudioSegmentEntity.LocalStorageStatus = .notStored,
         createdAt: Date = Date(),
         lastModifiedAt: Date = Date(),
         metadata: [String: Any]? = nil) {

        self.id = id
        self.questionId = questionId
        self.fileName = fileName
        self.localFileURL = localFileURL
        self.duration = duration
        self.storageStatus = storageStatus
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.metadata = metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        questionId = try container.decodeIfPresent(Int.self, forKey: .questionId)
        fileName = try container.decode(String.self, forKey: .fileName)
        localFileURL = try container.decodeIfPresent(URL.self, forKey: .localFileURL)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        storageStatus = try container.decode(AudioSegmentEntity.LocalStorageStatus.self, forKey: .storageStatus)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastModifiedAt = try container.decode(Date.self, forKey: .lastModifiedAt)
        metadata = nil // Cannot decode [String: Any] directly
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(questionId, forKey: .questionId)
        try container.encode(fileName, forKey: .fileName)
        try container.encodeIfPresent(localFileURL, forKey: .localFileURL)
        try container.encode(duration, forKey: .duration)
        try container.encode(storageStatus, forKey: .storageStatus)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastModifiedAt, forKey: .lastModifiedAt)
    }
}

// MARK: - Equatable Implementation
extension LocalAudioSegment: Equatable {
    static func == (lhs: LocalAudioSegment, rhs: LocalAudioSegment) -> Bool {
        return lhs.id == rhs.id &&
               lhs.questionId == rhs.questionId &&
               lhs.fileName == rhs.fileName &&
               lhs.localFileURL == rhs.localFileURL &&
               lhs.duration == rhs.duration &&
               lhs.storageStatus == rhs.storageStatus &&
               lhs.createdAt == rhs.createdAt &&
               lhs.lastModifiedAt == rhs.lastModifiedAt
        // Note: metadata is excluded from equality check as [String: Any] is not Equatable
    }
}

// MARK: - Data Manager Extension for Local Audio

extension DataManager {

    // MARK: - Local Audio Segment Operations

    func saveLocalAudioSegment(_ segment: LocalAudioSegment) {
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()

        // Try to find existing segment by questionId or id
        if let segmentId = segment.id {
            request.predicate = NSPredicate(format: "id == %d", segmentId)
        } else if let questionId = segment.questionId {
            request.predicate = NSPredicate(format: "question.id == %d", questionId)
        } else {
            // Create new segment
            let audioEntity = AudioSegmentEntity.createLocal(from: segment, in: context)
            save()
            return
        }

        request.fetchLimit = 1

        do {
            let existingEntities = try context.fetch(request)
            let audioEntity = existingEntities.first ?? AudioSegmentEntity.createLocal(from: segment, in: context)

            if existingEntities.first != nil {
                audioEntity.updateFromLocal(audioSegment: segment)
            }

            save()
        } catch {
            print("❌ Failed to save local audio segment: \(error)")
        }
    }

    func fetchLocalAudioSegments(for projectId: Int) -> [LocalAudioSegment] {
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "question.section.chapter.outline.project.id == %d AND localFileURL != nil",
            projectId
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AudioSegmentEntity.createdAt, ascending: false)]

        do {
            let audioEntities = try context.fetch(request)
            return audioEntities.map { $0.toLocalAudioSegment() }
        } catch {
            print("❌ Failed to fetch local audio segments: \(error)")
            return []
        }
    }

    func fetchLocalAudioSegment(questionId: Int, projectId: Int) -> LocalAudioSegment? {
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "question.id == %d AND question.section.chapter.outline.project.id == %d",
            questionId, projectId
        )
        request.fetchLimit = 1

        do {
            let audioEntities = try context.fetch(request)
            return audioEntities.first?.toLocalAudioSegment()
        } catch {
            print("❌ Failed to fetch local audio segment: \(error)")
            return nil
        }
    }

    func deleteLocalAudioSegment(questionId: Int, projectId: Int) -> Bool {
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "question.id == %d AND question.section.chapter.outline.project.id == %d",
            questionId, projectId
        )
        request.fetchLimit = 1

        do {
            let audioEntities = try context.fetch(request)

            for entity in audioEntities {
                // Remove local file first
                entity.removeLocalFile()
                // Then delete entity
                context.delete(entity)
            }

            save()
            return true
        } catch {
            print("❌ Failed to delete local audio segment: \(error)")
            return false
        }
    }

    func fetchPendingUploads() -> [LocalAudioSegment] {
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localStorageStatusRaw == %@", "pending_upload")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AudioSegmentEntity.createdAt, ascending: true)]

        do {
            let audioEntities = try context.fetch(request)
            return audioEntities.map { $0.toLocalAudioSegment() }
        } catch {
            print("❌ Failed to fetch pending uploads: \(error)")
            return []
        }
    }

    func cleanupFailedUploads(olderThan timeInterval: TimeInterval = 24 * 60 * 60) {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        let request: NSFetchRequest<AudioSegmentEntity> = AudioSegmentEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "localStorageStatusRaw == %@ AND lastModifiedAt < %@",
            "failed", cutoffDate as NSDate
        )

        do {
            let failedEntities = try context.fetch(request)

            for entity in failedEntities {
                entity.removeLocalFile()
                context.delete(entity)
            }

            if !failedEntities.isEmpty {
                save()
                print("🗑️ Cleaned up \(failedEntities.count) failed upload entities")
            }
        } catch {
            print("❌ Failed to cleanup failed uploads: \(error)")
        }
    }
}