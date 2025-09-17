import Foundation
import CoreData

extension AudioSegmentEntity {
    var uploadStatusEnum: AudioSegment.UploadStatus {
        get {
            AudioSegment.UploadStatus(rawValue: uploadStatus ?? "") ?? .pending
        }
        set {
            uploadStatus = newValue.rawValue
        }
    }
    
    func toAudioSegment() -> AudioSegment {
        return AudioSegment(
            id: Int(id),
            fileName: fileName ?? "",
            mimeType: mimeType ?? "",
            recordedDurationSeconds: recordedDurationSeconds,
            questionId: question?.id != nil ? Int(question!.id) : nil,
            uploadUrl: nil, // This is temporary/transient data
            uploadStatus: uploadStatusEnum,
            expiresAt: nil // This is temporary/transient data
        )
    }
    
    func updateFrom(audioSegment: AudioSegment) {
        self.id = Int32(audioSegment.id)
        self.fileName = audioSegment.fileName
        self.mimeType = audioSegment.mimeType
        self.recordedDurationSeconds = audioSegment.recordedDurationSeconds
        self.uploadStatus = audioSegment.uploadStatus.rawValue
    }
    
    func updateLocalFileInfo(localFileURL: URL, isUploaded: Bool) {
        self.localFileURL = localFileURL.absoluteString
        self.isUploaded = isUploaded
    }
    
    static func create(from audioSegment: AudioSegment, in context: NSManagedObjectContext) -> AudioSegmentEntity {
        let entity = AudioSegmentEntity(context: context)
        entity.updateFrom(audioSegment: audioSegment)
        return entity
    }
}