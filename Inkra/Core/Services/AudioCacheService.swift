import Foundation
import AVFoundation

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class AudioCacheService: ObservableObject {
    static let shared = AudioCacheService()
    
    @Published var downloadProgress: [Int: Double] = [:]
    @Published var cacheStatus: [Int: CacheStatus] = [:]
    
    private struct CacheEntry {
        let data: Data
        let timestamp: Date
        let audioSegmentId: Int?
        let questionId: Int?
        let vibeLogEntryId: Int?
    }
    
    enum CacheStatus {
        case notCached
        case downloading
        case cached
        case failed
    }
    
    private var cache: [String: CacheEntry] = [:]
    private let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    private let cleanupInterval: TimeInterval = 300 // 5 minutes
    private var cleanupTimer: Timer?
    
    private let fileManager = FileManager.default
    private var activeDownloads: [Int: URLSessionDownloadTask] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()
    
    private init() {
        createCacheDirectoryIfNeeded()
        startCleanupTimer()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Cache Keys
    
    private func cacheKey(for audioSegmentId: Int) -> String {
        return "segment_\(audioSegmentId)"
    }
    
    private func cacheKey(forQuestionId questionId: Int) -> String {
        return "question_\(questionId)"
    }
    
    private func cacheKey(forVibeLogEntryId entryId: Int) -> String {
        return "vibelog_\(entryId)"
    }
    
    // MARK: - Cache Operations
    
    func cacheAudioData(_ data: Data, audioSegmentId: Int? = nil, questionId: Int? = nil, vibeLogEntryId: Int? = nil) {
        let entry = CacheEntry(
            data: data,
            timestamp: Date(),
            audioSegmentId: audioSegmentId,
            questionId: questionId,
            vibeLogEntryId: vibeLogEntryId
        )
        
        // Store under all applicable keys
        if let segmentId = audioSegmentId {
            cache[cacheKey(for: segmentId)] = entry
        }
        if let qId = questionId {
            cache[cacheKey(forQuestionId: qId)] = entry
        }
        if let entryId = vibeLogEntryId {
            cache[cacheKey(forVibeLogEntryId: entryId)] = entry
        }
        
        print("📦 Cached audio data - segment: \(audioSegmentId ?? -1), question: \(questionId ?? -1), vibelog: \(vibeLogEntryId ?? -1)")
    }
    
    func getCachedAudioData(audioSegmentId: Int) -> Data? {
        return getCachedEntry(for: cacheKey(for: audioSegmentId))?.data
    }
    
    func getCachedAudioData(questionId: Int) -> Data? {
        return getCachedEntry(for: cacheKey(forQuestionId: questionId))?.data
    }
    
    func getCachedAudioData(vibeLogEntryId: Int) -> Data? {
        return getCachedEntry(for: cacheKey(forVibeLogEntryId: vibeLogEntryId))?.data
    }
    
    private func getCachedEntry(for key: String) -> CacheEntry? {
        guard let entry = cache[key] else { return nil }
        
        // Check if cache entry has expired
        if Date().timeIntervalSince(entry.timestamp) > cacheExpirationTime {
            cache.removeValue(forKey: key)
            print("🗑️ Cache expired for key: \(key)")
            return nil
        }
        
        print("✅ Cache hit for key: \(key)")
        return entry
    }
    
    func removeCachedAudio(audioSegmentId: Int) {
        cache.removeValue(forKey: cacheKey(for: audioSegmentId))
    }
    
    func removeCachedAudio(questionId: Int) {
        cache.removeValue(forKey: cacheKey(forQuestionId: questionId))
    }
    
    func removeCachedAudio(vibeLogEntryId: Int) {
        cache.removeValue(forKey: cacheKey(forVibeLogEntryId: vibeLogEntryId))
    }
    
    func clearAllCache() {
        cache.removeAll()
        print("🧹 Cleared all audio cache")
    }
    
    // MARK: - File-based Cache Operations
    
    func cacheAudioFile(from url: URL, audioSegmentId: Int? = nil, questionId: Int? = nil, vibeLogEntryId: Int? = nil) {
        Task {
            do {
                let data = try Data(contentsOf: url)
                cacheAudioData(data, audioSegmentId: audioSegmentId, questionId: questionId, vibeLogEntryId: vibeLogEntryId)
            } catch {
                print("❌ Failed to cache audio file: \(error)")
            }
        }
    }
    
    // MARK: - Polly Audio Persistent Cache
    
    private var pollyCacheDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("PollyAudioCache", isDirectory: true)
    }
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: pollyCacheDirectory.path) {
            try? fileManager.createDirectory(at: pollyCacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func pollyCacheFileURL(for questionId: Int, projectId: Int? = nil) -> URL {
        // Include project ID in filename to prevent cross-project contamination
        if let projectId = projectId {
            return pollyCacheDirectory.appendingPathComponent("p\(projectId)_q\(questionId).mp3")
        } else {
            // Fallback to old format for compatibility
            return pollyCacheDirectory.appendingPathComponent("question_\(questionId).mp3")
        }
    }
    
    func isPollyAudioCached(for questionId: Int) -> Bool {
        let fileURL = pollyCacheFileURL(for: questionId)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    func getCachedPollyAudioURL(for questionId: Int, projectId: Int? = nil) -> URL? {
        // Try project-specific cache first
        if let projectId = projectId {
            let projectSpecificURL = pollyCacheFileURL(for: questionId, projectId: projectId)
            if fileManager.fileExists(atPath: projectSpecificURL.path) {
                return projectSpecificURL
            }
        }
        
        // Fallback to old format for backward compatibility
        let legacyURL = pollyCacheFileURL(for: questionId)
        return fileManager.fileExists(atPath: legacyURL.path) ? legacyURL : nil
    }
    
    func downloadPollyAudio(for questionId: Int, from urlString: String, projectId: Int? = nil) async throws {
        guard let url = URL(string: urlString) else {
            cacheStatus[questionId] = .failed
            throw AudioCacheError.invalidURL
        }
        
        if isPollyAudioCached(for: questionId) {
            cacheStatus[questionId] = .cached
            return
        }
        
        if activeDownloads[questionId] != nil {
            return
        }
        
        cacheStatus[questionId] = .downloading
        downloadProgress[questionId] = 0.0
        
        do {
            let (tempURL, _) = try await urlSession.download(from: url)
            let destinationURL = pollyCacheFileURL(for: questionId, projectId: projectId)
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            
            cacheStatus[questionId] = .cached
            downloadProgress[questionId] = 1.0
            activeDownloads.removeValue(forKey: questionId)
            
            let projectInfo = projectId.map { " (project \($0))" } ?? ""
            print("✅ Successfully cached Polly audio for question \(questionId)\(projectInfo)")
            
        } catch {
            cacheStatus[questionId] = .failed
            downloadProgress.removeValue(forKey: questionId)
            activeDownloads.removeValue(forKey: questionId)
            
            print("❌ Failed to cache Polly audio for question \(questionId): \(error)")
            throw error
        }
    }
    
    func downloadMultiplePollyAudio(urlMap: [Int: String]) async {
        // Sort by question ID to prioritize early questions
        let sortedQuestions = urlMap.sorted { $0.key < $1.key }
        
        await withTaskGroup(of: Void.self) { group in
            for (questionId, urlString) in sortedQuestions {
                // Skip if already cached
                if isPollyAudioCached(for: questionId) {
                    print("✅ Question \(questionId) already cached, skipping download")
                    continue
                }
                
                group.addTask {
                    do {
                        try await self.downloadPollyAudio(for: questionId, from: urlString)
                    } catch {
                        print("Failed to download Polly audio for question \(questionId): \(error)")
                    }
                }
            }
        }
    }
    
    func cancelPollyDownload(for questionId: Int) {
        activeDownloads[questionId]?.cancel()
        activeDownloads.removeValue(forKey: questionId)
        cacheStatus[questionId] = .notCached
        downloadProgress.removeValue(forKey: questionId)
    }
    
    func clearPollyCache() {
        for (questionId, _) in activeDownloads {
            cancelPollyDownload(for: questionId)
        }
        
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: pollyCacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in cachedFiles {
                try fileManager.removeItem(at: fileURL)
            }
            
            for key in cacheStatus.keys {
                cacheStatus[key] = .notCached
            }
            downloadProgress.removeAll()
            print("✅ Polly audio cache cleared")
        } catch {
            print("❌ Failed to clear Polly audio cache: \(error)")
        }
    }
    
    func clearCacheForNewInterview(projectId: Int, projectTitle: String) {
        print("\n🧽💬 CLEARING CACHE FOR NEW INTERVIEW")
        print(String(repeating: "━", count: 50))
        print("🆔 Project ID: \(projectId)")
        print("📝 Project: \"\(projectTitle)\"")
        
        // Cancel all active downloads
        let activeCount = activeDownloads.count
        for (questionId, _) in activeDownloads {
            cancelPollyDownload(for: questionId)
        }
        if activeCount > 0 {
            print("⏹️ Cancelled \(activeCount) active downloads")
        }
        
        // Clear memory cache
        let memoryCacheCount = cache.count
        cache.removeAll()
        if memoryCacheCount > 0 {
            print("🧽 Cleared \(memoryCacheCount) memory cache entries")
        }
        
        // Clear disk cache
        var diskCacheCount = 0
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: pollyCacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in cachedFiles {
                try fileManager.removeItem(at: fileURL)
                diskCacheCount += 1
            }
            if diskCacheCount > 0 {
                print("📋 Deleted \(diskCacheCount) cached audio files")
            }
        } catch {
            print("❌ Failed to clear disk cache: \(error)")
        }
        
        // Clear NativeVoiceService preloaded items  
        NativeVoiceService.shared.clearPreloadedItems()
        
        // Reset all status tracking
        cacheStatus.removeAll()
        downloadProgress.removeAll()
        
        print("✅ Cache completely cleared for new interview")
        print(String(repeating: "━", count: 50))
        print("")
    }
    
    func getPollyCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: pollyCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        return totalSize
    }
    
    func cleanupExpiredPollyCache(olderThan days: Int = 7) {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(
                at: pollyCacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )
            
            for fileURL in cachedFiles {
                let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = resourceValues.contentModificationDate,
                   modificationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    
                    if let questionId = extractQuestionId(from: fileURL.lastPathComponent) {
                        cacheStatus.removeValue(forKey: questionId)
                    }
                }
            }
            print("✅ Cleaned up expired Polly audio cache files")
        } catch {
            print("❌ Failed to cleanup expired Polly cache: \(error)")
        }
    }
    
    func cleanupCacheForDeletedProject(questionIds: [Int]) {
        print("🗑️ Cleaning up cached audio for deleted project with \(questionIds.count) questions")
        
        var cleanedCount = 0
        for questionId in questionIds {
            let fileURL = pollyCacheFileURL(for: questionId)
            
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    try fileManager.removeItem(at: fileURL)
                    cacheStatus.removeValue(forKey: questionId)
                    downloadProgress.removeValue(forKey: questionId)
                    cleanedCount += 1
                    print("🗑️ Removed cached audio for question \(questionId)")
                } catch {
                    print("❌ Failed to remove cached audio for question \(questionId): \(error)")
                }
            }
            
            // Also cancel any active downloads
            if let downloadTask = activeDownloads[questionId] {
                downloadTask.cancel()
                activeDownloads.removeValue(forKey: questionId)
                print("⏹️ Cancelled download for question \(questionId)")
            }
        }
        
        print("✅ Cleaned up cached audio for \(cleanedCount) questions from deleted project")
    }
    
    private func extractQuestionId(from filename: String) -> Int? {
        let pattern = #"question_(\d+)\.mp3"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: filename.utf16.count)
        
        if let match = regex?.firstMatch(in: filename, range: range),
           let questionIdRange = Range(match.range(at: 1), in: filename) {
            return Int(String(filename[questionIdRange]))
        }
        return nil
    }
    
    // MARK: - Cleanup
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupExpiredEntries()
            }
        }
    }
    
    private func cleanupExpiredEntries() {
        let now = Date()
        var keysToRemove: [String] = []
        
        for (key, entry) in cache {
            if now.timeIntervalSince(entry.timestamp) > cacheExpirationTime {
                keysToRemove.append(key)
            }
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 Cleaned up \(keysToRemove.count) expired cache entries")
        }
    }
    
    // MARK: - Cache Info
    
    var cacheSize: Int {
        cache.reduce(0) { $0 + $1.value.data.count }
    }
    
    var cacheCount: Int {
        cache.count
    }
    
    func printCacheInfo() {
        print("📊 Audio Cache Info:")
        print("   - Entries: \(cacheCount)")
        print("   - Size: \(ByteCountFormatter.string(fromByteCount: Int64(cacheSize), countStyle: .file))")
        print("   - Polly Cache Size: \(ByteCountFormatter.string(fromByteCount: getPollyCacheSize(), countStyle: .file))")
    }
    
    func getCacheStats() -> (memoryEntries: Int, diskFiles: Int, activeDownloads: Int) {
        let diskFiles = (try? fileManager.contentsOfDirectory(at: pollyCacheDirectory, includingPropertiesForKeys: nil).count) ?? 0
        return (memoryEntries: cache.count, diskFiles: diskFiles, activeDownloads: activeDownloads.count)
    }
}

enum AudioCacheError: LocalizedError {
    case invalidURL
    case downloadFailed
    case fileSystemError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid audio URL"
        case .downloadFailed:
            return "Failed to download audio"
        case .fileSystemError:
            return "File system error"
        }
    }
}