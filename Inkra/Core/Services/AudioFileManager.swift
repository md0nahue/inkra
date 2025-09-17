import Foundation

class AudioFileManager {
    static let shared = AudioFileManager()
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let audioDirectory: URL
    private let maxAudioAge: TimeInterval = 6 * 60 * 60 // 6 hours in seconds
    
    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioDirectory = documentsDirectory.appendingPathComponent("VibeLogAudio", isDirectory: true)
        
        // Create audio directory if it doesn't exist
        try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        
        // Start cleanup timer
        startCleanupTimer()
    }
    
    // MARK: - Public Methods
    
    func generateAudioFileURL() -> URL {
        let fileName = "vibelog_\(UUID().uuidString).m4a"
        return audioDirectory.appendingPathComponent(fileName)
    }
    
    func saveAudioFile(from sourceURL: URL) -> URL? {
        let destinationURL = generateAudioFileURL()
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Failed to save audio file: \(error)")
            return nil
        }
    }
    
    func cleanupOldAudioFiles() {
        do {
            let audioFiles = try fileManager.contentsOfDirectory(at: audioDirectory, 
                                                                includingPropertiesForKeys: [.creationDateKey],
                                                                options: .skipsHiddenFiles)
            
            let now = Date()
            
            for fileURL in audioFiles {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date {
                    
                    let age = now.timeIntervalSince(creationDate)
                    
                    if age > maxAudioAge {
                        try? fileManager.removeItem(at: fileURL)
                        print("Cleaned up old audio file: \(fileURL.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("Failed to cleanup audio files: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func startCleanupTimer() {
        // Run cleanup every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.cleanupOldAudioFiles()
        }
        
        // Also run cleanup on app launch
        cleanupOldAudioFiles()
    }
}