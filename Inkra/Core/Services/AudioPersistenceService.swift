import Foundation

protocol AudioPersistenceServiceProtocol {
    func saveAudioSegment(_ segmentInfo: AudioSegmentInfo, for projectId: Int) async throws
    func loadAudioSegments(for projectId: Int) async throws -> [Int: AudioSegmentInfo]
    func updateUploadStatus(for questionId: Int, projectId: Int, audioSegmentId: Int?, isUploaded: Bool) async throws
    func deleteAudioSegment(for questionId: Int, projectId: Int) async throws
    func cleanupExpiredSegments() async throws
}

class AudioPersistenceService: AudioPersistenceServiceProtocol {
    private let fileManager = FileManager.default
    private let dataManager = DataManager.shared
    
    // Directory for persistent audio storage
    private var audioStorageDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("AudioSegments")
    }
    
    init() {
        setupStorageDirectory()
    }
    
    private func setupStorageDirectory() {
        do {
            try fileManager.createDirectory(at: audioStorageDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create audio storage directory: \(error)")
        }
    }
    
    func saveAudioSegment(_ segmentInfo: AudioSegmentInfo, for projectId: Int) async throws {
        // For text responses, we don't need to handle file copying
        if segmentInfo.textResponse != nil && segmentInfo.localURL == nil {
            // Text responses don't need file persistence
            // The text response is already stored in the segmentInfo
            return
        }
        
        // Create persistent file path for audio files
        let persistentURL = audioStorageDirectory
            .appendingPathComponent("\(projectId)")
            .appendingPathComponent("\(segmentInfo.questionId).m4a")
        
        // Ensure project directory exists
        let projectDir = persistentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: projectDir, withIntermediateDirectories: true)
        
        // Copy temporary file to persistent location
        guard let localURL = segmentInfo.localURL else {
            throw NSError(domain: "AudioPersistenceService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No local URL provided for audio segment"])
        }
        
        if fileManager.fileExists(atPath: localURL.path) {
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: persistentURL.path) {
                try fileManager.removeItem(at: persistentURL)
            }
            
            try fileManager.copyItem(at: localURL, to: persistentURL)
            
            // Create updated segment info with persistent URL
            let persistentSegmentInfo = AudioSegmentInfo(
                questionId: segmentInfo.questionId,
                localURL: persistentURL,
                duration: segmentInfo.duration,
                audioSegmentId: segmentInfo.audioSegmentId,
                isUploaded: segmentInfo.isUploaded,
                textResponse: segmentInfo.textResponse
            )
            
            // Save metadata to Core Data
            await MainActor.run {
                dataManager.saveAudioSegmentLocalInfo(
                    questionId: persistentSegmentInfo.questionId,
                    projectId: projectId,
                    localFileURL: persistentURL,
                    isUploaded: persistentSegmentInfo.isUploaded,
                    audioSegmentId: persistentSegmentInfo.audioSegmentId
                )
            }
        }
    }
    
    func loadAudioSegments(for projectId: Int) async throws -> [Int: AudioSegmentInfo] {
        var segments: [Int: AudioSegmentInfo] = [:]
        
        // Load from Core Data
        let audioSegmentData = await MainActor.run {
            dataManager.fetchAudioSegmentsWithLocalFiles(for: projectId)
        }
        
        for (questionId, localFileURL, isUploaded, audioSegmentId) in audioSegmentData {
            // Verify file still exists
            if fileManager.fileExists(atPath: localFileURL.path) {
                // Get file attributes for duration
                var duration: TimeInterval = 0
                if let attributes = try? fileManager.attributesOfItem(atPath: localFileURL.path),
                   let fileSize = attributes[.size] as? NSNumber {
                    // Rough estimate: assume 16kbps for m4a
                    duration = Double(fileSize.intValue) / (16000 / 8)
                }
                
                let segmentInfo = AudioSegmentInfo(
                    questionId: questionId,
                    localURL: localFileURL,
                    duration: duration,
                    audioSegmentId: audioSegmentId,
                    isUploaded: isUploaded,
                    textResponse: nil
                )
                
                segments[questionId] = segmentInfo
            }
        }
        
        return segments
    }
    
    func updateUploadStatus(for questionId: Int, projectId: Int, audioSegmentId: Int?, isUploaded: Bool) async throws {
        await MainActor.run {
            // Just update the Core Data record
            if let localInfo = dataManager.fetchAudioSegmentsWithLocalFiles(for: projectId).first(where: { $0.questionId == questionId }) {
                dataManager.saveAudioSegmentLocalInfo(
                    questionId: questionId,
                    projectId: projectId,
                    localFileURL: localInfo.localFileURL,
                    isUploaded: isUploaded,
                    audioSegmentId: audioSegmentId ?? localInfo.audioSegmentId
                )
            }
        }
    }
    
    func deleteAudioSegment(for questionId: Int, projectId: Int) async throws {
        // Get segment info from Core Data first
        let segments = await MainActor.run {
            dataManager.fetchAudioSegmentsWithLocalFiles(for: projectId)
        }
        
        if let segmentInfo = segments.first(where: { $0.questionId == questionId }) {
            // Delete physical file
            if fileManager.fileExists(atPath: segmentInfo.localFileURL.path) {
                try fileManager.removeItem(at: segmentInfo.localFileURL)
            }
            
            // Remove from Core Data
            await MainActor.run {
                dataManager.deleteAudioSegmentLocalInfo(questionId: questionId, projectId: projectId)
            }
        }
    }
    
    func cleanupExpiredSegments() async throws {
        let projectDirs = try fileManager.contentsOfDirectory(at: audioStorageDirectory, includingPropertiesForKeys: nil)
        
        for projectDir in projectDirs {
            let files = try fileManager.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = resourceValues.creationDate,
                   Date().timeIntervalSince(creationDate) > 7 * 24 * 60 * 60 { // 7 days
                    try fileManager.removeItem(at: file)
                }
            }
        }
    }
}

// MARK: - AudioSegmentInfo Extension for Persistence
@available(iOS 15.0, macOS 11.0, *)
extension AudioSegmentInfo {
    var persistenceKey: String {
        return "\(questionId)_\(Int(Date().timeIntervalSince1970))"
    }
    
    func withUpdatedURL(_ newURL: URL) -> AudioSegmentInfo {
        return AudioSegmentInfo(
            questionId: self.questionId,
            localURL: newURL,
            duration: self.duration,
            audioSegmentId: self.audioSegmentId,
            isUploaded: self.isUploaded,
            textResponse: self.textResponse
        )
    }
}