import Foundation
import Combine

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class UploadManager: ObservableObject {
    static let shared = UploadManager()
    
    @Published var uploadProgress: [Int: Double] = [:]
    @Published var uploadStatuses: [Int: UploadStatus] = [:]
    @Published var queuedUploadsCount: Int = 0
    
    enum UploadStatus {
        case idle
        case queuedOffline
        case uploading
        case success
        case failed(Error)
    }
    
    nonisolated(unsafe) private let audioService: AudioServiceProtocol
    nonisolated(unsafe) private let persistenceService: AudioPersistenceServiceProtocol
    nonisolated(unsafe) private let backgroundUploadService: BackgroundUploadServiceProtocol
    private let networkService: NetworkConnectivityService
    private let audioCache = AudioCacheService.shared
    
    private var uploadTasks: [Int: Task<Void, Never>] = [:]
    private var activeUploads: [Int: (segmentInfo: AudioSegmentInfo, projectId: Int)] = [:]
    private var queuedUploads: [(segmentInfo: AudioSegmentInfo, projectId: Int)] = []
    nonisolated(unsafe) private var networkConnectivityObserver: NSObjectProtocol?
    
    init(
        audioService: AudioServiceProtocol = AudioService(),
        persistenceService: AudioPersistenceServiceProtocol = AudioPersistenceService(),
        backgroundUploadService: BackgroundUploadServiceProtocol = BackgroundUploadService.shared,
        networkService: NetworkConnectivityService = NetworkConnectivityService.shared
    ) {
        self.audioService = audioService
        self.persistenceService = persistenceService
        self.backgroundUploadService = backgroundUploadService
        self.networkService = networkService
        
        // Set ourselves as the delegate
        self.backgroundUploadService.setDelegate(self)
        
        // Setup network connectivity monitoring
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkConnectivityObserver = NotificationCenter.default.addObserver(
            forName: .networkConnectivityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleNetworkConnectivityChange(notification)
            }
        }
    }
    
    private func handleNetworkConnectivityChange(_ notification: Notification) {
        guard let isConnected = notification.userInfo?["isConnected"] as? Bool else { return }
        
        if isConnected && !queuedUploads.isEmpty {
            print("📶 Network restored, processing \(queuedUploads.count) queued uploads")
            processQueuedUploads()
        }
    }
    
    deinit {
        if let observer = networkConnectivityObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    func uploadAudioSegment(_ segmentInfo: AudioSegmentInfo, for projectId: Int) async {
        let questionId = segmentInfo.questionId
        
        // Check if device is offline
        if !networkService.isConnected {
            // Queue the upload for later processing
            queuedUploads.append((segmentInfo: segmentInfo, projectId: projectId))
            uploadStatuses[questionId] = .queuedOffline
            queuedUploadsCount = queuedUploads.count
            
            // Save to Core Data with isUploaded = false
            do {
                try await persistenceService.updateUploadStatus(
                    for: questionId,
                    projectId: projectId,
                    audioSegmentId: segmentInfo.audioSegmentId,
                    isUploaded: false
                )
                print("📱 Offline: Queued upload for question \(questionId)")
            } catch {
                uploadStatuses[questionId] = .failed(error)
                print("❌ Failed to save offline upload: \(error)")
            }
            return
        }
        
        // Cancel any existing upload task
        uploadTasks[questionId]?.cancel()
        
        // Create new upload task
        let task = Task {
            await performUpload(segmentInfo, projectId: projectId)
        }
        
        uploadTasks[questionId] = task
        await task.value
    }
    
    func processQueuedUploads() {
        guard networkService.isConnected && !queuedUploads.isEmpty else { return }
        
        let uploadsToProcess = queuedUploads
        queuedUploads.removeAll()
        queuedUploadsCount = 0
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                for (segmentInfo, projectId) in uploadsToProcess {
                    group.addTask { [weak self] in
                        await self?.performUpload(segmentInfo, projectId: projectId)
                    }
                }
            }
        }
    }
    
    func retryFailedUploads(for projectId: Int, segments: [AudioSegmentInfo]) async {
        let failedSegments = segments.filter { !$0.isUploaded }
        
        await withTaskGroup(of: Void.self) { group in
            for segment in failedSegments {
                group.addTask { [weak self] in
                    await self?.uploadAudioSegment(segment, for: projectId)
                }
            }
        }
    }
    
    func checkForPendingUploads(for projectId: Int) async {
        // Check Core Data for any segments that haven't been uploaded
        let pendingSegments = DataManager.shared.fetchAudioSegmentsWithLocalFiles(for: projectId)
            .filter { !$0.isUploaded }
        
        if !pendingSegments.isEmpty {
            print("📤 Found \(pendingSegments.count) pending uploads for project \(projectId)")
            
            // If we're online, process them immediately
            if networkService.isConnected {
                await withTaskGroup(of: Void.self) { group in
                    for (questionId, localFileURL, _, audioSegmentId) in pendingSegments {
                        group.addTask { [weak self] in
                            // Get file duration
                            var duration: TimeInterval = 0
                            if let attributes = try? FileManager.default.attributesOfItem(atPath: localFileURL.path),
                               let fileSize = attributes[.size] as? NSNumber {
                                // Rough estimate: assume 16kbps for m4a
                                duration = Double(fileSize.intValue) / (16000 / 8)
                            }
                            
                            let segmentInfo = AudioSegmentInfo(
                                questionId: questionId,
                                localURL: localFileURL,
                                duration: duration,
                                audioSegmentId: audioSegmentId,
                                isUploaded: false,
                                textResponse: nil
                            )
                            
                            await self?.uploadAudioSegment(segmentInfo, for: projectId)
                        }
                    }
                }
            } else {
                // If we're offline, queue them
                for (questionId, localFileURL, _, audioSegmentId) in pendingSegments {
                    // Get file duration
                    var duration: TimeInterval = 0
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: localFileURL.path),
                       let fileSize = attributes[.size] as? NSNumber {
                        // Rough estimate: assume 16kbps for m4a
                        duration = Double(fileSize.intValue) / (16000 / 8)
                    }
                    
                    let segmentInfo = AudioSegmentInfo(
                        questionId: questionId,
                        localURL: localFileURL,
                        duration: duration,
                        audioSegmentId: audioSegmentId,
                        isUploaded: false,
                        textResponse: nil
                    )
                    
                    queuedUploads.append((segmentInfo: segmentInfo, projectId: projectId))
                    uploadStatuses[questionId] = .queuedOffline
                }
                
                queuedUploadsCount = queuedUploads.count
                print("📱 Offline: Queued \(queuedUploadsCount) pending uploads")
            }
        }
    }
    
    func cancelUpload(for questionId: Int) {
        uploadTasks[questionId]?.cancel()
        uploadTasks.removeValue(forKey: questionId)
        uploadProgress.removeValue(forKey: questionId)
        uploadStatuses.removeValue(forKey: questionId)
    }
    
    func getUploadStatus(for questionId: Int) -> UploadStatus {
        return uploadStatuses[questionId] ?? .idle
    }
    
    func getUploadProgress(for questionId: Int) -> Double {
        return uploadProgress[questionId] ?? 0.0
    }
    
    // MARK: - Private Methods
    
    private func performUpload(_ segmentInfo: AudioSegmentInfo, projectId: Int) async {
        let questionId = segmentInfo.questionId
        
        do {
            // Update status and progress
            uploadStatuses[questionId] = .uploading
            uploadProgress[questionId] = 0.1
            
            // Request upload URL from backend
            let fileName = "question_\(questionId)_\(Date().timeIntervalSince1970).m4a"
            let uploadResponse = try await audioService.requestUploadURL(
                projectId: projectId,
                fileName: fileName,
                mimeType: "audio/m4a",
                duration: segmentInfo.duration,
                questionId: questionId
            )
            
            uploadProgress[questionId] = 0.3
            
            // Create updated segment info with audioSegmentId
            let updatedSegmentInfo = AudioSegmentInfo(
                questionId: segmentInfo.questionId,
                localURL: segmentInfo.localURL,
                duration: segmentInfo.duration,
                audioSegmentId: uploadResponse.audioSegmentId,
                isUploaded: false,
                textResponse: segmentInfo.textResponse
            )
            
            // Store for later use in delegate callbacks
            activeUploads[questionId] = (updatedSegmentInfo, projectId)
            
            // Update persistence with audioSegmentId
            try await persistenceService.updateUploadStatus(
                for: questionId,
                projectId: projectId,
                audioSegmentId: uploadResponse.audioSegmentId,
                isUploaded: false
            )
            
            uploadProgress[questionId] = 0.5
            
            // Read audio data
            guard let localURL = segmentInfo.localURL else {
                throw NSError(domain: "UploadManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No local URL provided for audio segment"])
            }
            let audioData = try Data(contentsOf: localURL)
            
            // Cache the audio data for immediate playback
            audioCache.cacheAudioData(
                audioData,
                audioSegmentId: uploadResponse.audioSegmentId,
                questionId: segmentInfo.questionId
            )
            
            // Start background upload
            try await backgroundUploadService.uploadAudio(
                data: audioData,
                to: uploadResponse.uploadUrl,
                for: questionId
            )
            
            // Background upload started successfully
            uploadProgress[questionId] = 0.6
            
        } catch {
            uploadStatuses[questionId] = .failed(error)
            uploadProgress.removeValue(forKey: questionId)
            activeUploads.removeValue(forKey: questionId)
            
            // Notify backend of failure
            await notifyUploadFailure(for: segmentInfo, projectId: projectId, error: error)
        }
    }
    
    private func notifyUploadSuccess(for segmentInfo: AudioSegmentInfo, projectId: Int) async {
        do {
            let _ = try await audioService.notifyUploadComplete(
                projectId: projectId,
                audioSegmentId: segmentInfo.audioSegmentId ?? 0,
                success: true,
                errorMessage: nil
            )
            
            // Update persistence
            try await persistenceService.updateUploadStatus(
                for: segmentInfo.questionId,
                projectId: projectId,
                audioSegmentId: segmentInfo.audioSegmentId ?? 0,
                isUploaded: true
            )
            
            uploadStatuses[segmentInfo.questionId] = .success
            uploadProgress[segmentInfo.questionId] = 1.0
            
            print("✅ Upload completed successfully for question \(segmentInfo.questionId)")
            
        } catch {
            uploadStatuses[segmentInfo.questionId] = .failed(error)
            print("❌ Failed to notify upload success: \(error)")
        }
    }
    
    private func notifyUploadFailure(for segmentInfo: AudioSegmentInfo, projectId: Int, error: Error) async {
        do {
            let _ = try await audioService.notifyUploadComplete(
                projectId: projectId,
                audioSegmentId: segmentInfo.audioSegmentId ?? 0,
                success: false,
                errorMessage: error.localizedDescription
            )
        } catch {
            print("❌ Failed to notify upload failure: \(error)")
        }
    }
}

// MARK: - BackgroundUploadDelegate

@available(iOS 15.0, macOS 11.0, *)
extension UploadManager: BackgroundUploadDelegate {
    func uploadDidComplete(for questionId: Int, success: Bool, error: Error?) {
        if success {
            // Get the segment info and project ID from our tracking
            if let (segmentInfo, projectId) = activeUploads[questionId] {
                Task {
                    await notifyUploadSuccess(for: segmentInfo, projectId: projectId)
                }
                activeUploads.removeValue(forKey: questionId)
            } else {
                uploadStatuses[questionId] = .success
                uploadProgress[questionId] = 1.0
                print("✅ Background upload completed for question \(questionId)")
            }
        } else {
            uploadStatuses[questionId] = .failed(error ?? NetworkError.unknown(NSError(domain: "UploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown upload error"])))
            uploadProgress.removeValue(forKey: questionId)
            activeUploads.removeValue(forKey: questionId)
            print("❌ Background upload failed for question \(questionId): \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    func uploadDidProgress(for questionId: Int, progress: Double) {
        // Update progress: 0.6 (initial) + 0.4 * actual progress = 0.6 to 1.0
        uploadProgress[questionId] = 0.6 + (0.4 * progress)
    }
}