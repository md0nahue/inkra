import Foundation
import AVFoundation
import Combine

@MainActor
class LocalAudioManager: NSObject, ObservableObject {
    static let shared = LocalAudioManager()

    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingProgress: TimeInterval = 0
    @Published var availableAudioSegments: [AudioSegmentInfo] = []
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let audioDirectory: URL
    private let interviewDirectory: URL
    private let metadataDirectory: URL

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Directory Structure
    /*
     Documents/
     ├── InkraAudio/
     │   ├── Interviews/
     │   │   ├── Interview_[ProjectID]/
     │   │   │   ├── Question_[QuestionID]_[timestamp].m4a
     │   │   │   ├── Question_[QuestionID]_[timestamp].m4a
     │   │   │   └── metadata.json
     │   │   └── ...
     │   ├── Exports/
     │   │   └── [ProjectName]_[timestamp].m4a
     │   └── Temp/
     */

    private override init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioDirectory = documentsDirectory.appendingPathComponent("InkraAudio", isDirectory: true)
        interviewDirectory = audioDirectory.appendingPathComponent("Interviews", isDirectory: true)
        metadataDirectory = audioDirectory.appendingPathComponent("Metadata", isDirectory: true)

        super.init()

        setupDirectoryStructure()
        setupAudioSession()
        loadAvailableSegments()
    }

    // MARK: - Directory Management

    private func setupDirectoryStructure() {
        let directories = [
            audioDirectory,
            interviewDirectory,
            audioDirectory.appendingPathComponent("Exports", isDirectory: true),
            audioDirectory.appendingPathComponent("Temp", isDirectory: true),
            metadataDirectory
        ]

        for directory in directories {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create directory \(directory.path): \(error)")
                errorMessage = "Failed to setup audio directories"
            }
        }
    }

    private func getInterviewDirectory(for projectId: Int) -> URL {
        return interviewDirectory.appendingPathComponent("Interview_\(projectId)", isDirectory: true)
    }

    private func ensureInterviewDirectory(for projectId: Int) -> URL? {
        let directory = getInterviewDirectory(for: projectId)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            print("Failed to create interview directory: \(error)")
            errorMessage = "Failed to create interview directory"
            return nil
        }
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        #if canImport(UIKit)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
            errorMessage = "Failed to setup audio session"
        }
        #endif
    }

    // MARK: - Recording Methods

    func startRecording(for questionId: Int, in projectId: Int) async -> Bool {
        guard !isRecording else { return false }

        guard let interviewDir = ensureInterviewDirectory(for: projectId) else {
            return false
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = "Question_\(questionId)_\(timestamp).m4a"
        let audioURL = interviewDir.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            let success = audioRecorder?.record() ?? false
            if success {
                isRecording = true
                recordingProgress = 0
                startRecordingTimer()

                // Save metadata
                await saveAudioMetadata(
                    questionId: questionId,
                    projectId: projectId,
                    fileName: fileName,
                    audioURL: audioURL
                )
            }

            return success

        } catch {
            print("Failed to start recording: \(error)")
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            return false
        }
    }

    func stopRecording() async -> AudioSegmentInfo? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        recorder.stop()
        stopRecordingTimer()

        let duration = recorder.currentTime
        let url = recorder.url

        isRecording = false
        audioRecorder = nil

        // Find the corresponding metadata
        if let segmentInfo = availableAudioSegments.first(where: { $0.localURL == url }) {
            let updatedInfo = AudioSegmentInfo(
                questionId: segmentInfo.questionId,
                localURL: url,
                duration: duration,
                audioSegmentId: segmentInfo.audioSegmentId,
                isUploaded: false,
                textResponse: segmentInfo.textResponse
            )

            // Update the list
            if let index = availableAudioSegments.firstIndex(where: { $0.localURL == url }) {
                availableAudioSegments[index] = updatedInfo
            }

            return updatedInfo
        }

        return nil
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      let recorder = self.audioRecorder else { return }

                self.recordingProgress = recorder.currentTime
                recorder.updateMeters()
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Audio Segment Management

    func saveAudioSegment(
        questionId: Int,
        projectId: Int,
        from sourceURL: URL,
        duration: TimeInterval = 0
    ) async -> AudioSegmentInfo? {

        guard let interviewDir = ensureInterviewDirectory(for: projectId) else {
            return nil
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = "Question_\(questionId)_\(timestamp).m4a"
        let destinationURL = interviewDir.appendingPathComponent(fileName)

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)

            let segmentInfo = AudioSegmentInfo(
                questionId: questionId,
                localURL: destinationURL,
                duration: duration,
                audioSegmentId: nil,
                isUploaded: false
            )

            await saveAudioMetadata(
                questionId: questionId,
                projectId: projectId,
                fileName: fileName,
                audioURL: destinationURL,
                duration: duration
            )

            availableAudioSegments.append(segmentInfo)
            return segmentInfo

        } catch {
            print("Failed to save audio segment: \(error)")
            errorMessage = "Failed to save audio segment"
            return nil
        }
    }

    func getAudioSegments(for projectId: Int) -> [AudioSegmentInfo] {
        return availableAudioSegments.filter { segment in
            guard let url = segment.localURL else { return false }
            return url.path.contains("Interview_\(projectId)")
        }
    }

    func getAudioSegment(for questionId: Int, in projectId: Int) -> AudioSegmentInfo? {
        return availableAudioSegments.first { segment in
            segment.questionId == questionId &&
            segment.localURL?.path.contains("Interview_\(projectId)") == true
        }
    }

    func deleteAudioSegment(_ segmentInfo: AudioSegmentInfo) async -> Bool {
        guard let url = segmentInfo.localURL else { return false }

        do {
            try fileManager.removeItem(at: url)

            // Remove from available segments
            availableAudioSegments.removeAll { $0.localURL == url }

            // Update metadata
            await removeAudioMetadata(for: segmentInfo)

            return true
        } catch {
            print("Failed to delete audio segment: \(error)")
            errorMessage = "Failed to delete audio segment"
            return false
        }
    }

    // MARK: - Metadata Management

    private struct AudioMetadata: Codable {
        let questionId: Int
        let projectId: Int
        let fileName: String
        let audioURL: String
        let duration: TimeInterval
        let createdAt: Date
        let isUploaded: Bool
        let audioSegmentId: Int?
    }

    private func saveAudioMetadata(
        questionId: Int,
        projectId: Int,
        fileName: String,
        audioURL: URL,
        duration: TimeInterval = 0
    ) async {
        let metadata = AudioMetadata(
            questionId: questionId,
            projectId: projectId,
            fileName: fileName,
            audioURL: audioURL.absoluteString,
            duration: duration,
            createdAt: Date(),
            isUploaded: false,
            audioSegmentId: nil
        )

        let metadataFileName = "metadata_\(questionId)_\(projectId).json"
        let metadataURL = metadataDirectory.appendingPathComponent(metadataFileName)

        do {
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: metadataURL)
        } catch {
            print("Failed to save audio metadata: \(error)")
        }
    }

    private func removeAudioMetadata(for segmentInfo: AudioSegmentInfo) async {
        let metadataFileName = "metadata_\(segmentInfo.questionId)_*.json"

        do {
            let metadataFiles = try fileManager.contentsOfDirectory(at: metadataDirectory, includingPropertiesForKeys: nil)
            let matchingFiles = metadataFiles.filter { url in
                url.lastPathComponent.hasPrefix("metadata_\(segmentInfo.questionId)_")
            }

            for file in matchingFiles {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("Failed to remove audio metadata: \(error)")
        }
    }

    private func loadAvailableSegments() {
        Task {
            var segments: [AudioSegmentInfo] = []

            do {
                let metadataFiles = try fileManager.contentsOfDirectory(at: metadataDirectory, includingPropertiesForKeys: nil)

                for metadataFile in metadataFiles {
                    if let data = try? Data(contentsOf: metadataFile),
                       let metadata = try? JSONDecoder().decode(AudioMetadata.self, from: data),
                       let audioURL = URL(string: metadata.audioURL),
                       fileManager.fileExists(atPath: audioURL.path) {

                        let segmentInfo = AudioSegmentInfo(
                            questionId: metadata.questionId,
                            localURL: audioURL,
                            duration: metadata.duration,
                            audioSegmentId: metadata.audioSegmentId,
                            isUploaded: metadata.isUploaded
                        )

                        segments.append(segmentInfo)
                    }
                }

                await MainActor.run {
                    self.availableAudioSegments = segments
                }

            } catch {
                print("Failed to load available segments: \(error)")
            }
        }
    }

    // MARK: - File Organization

    func cleanupOldAudioFiles(olderThan timeInterval: TimeInterval = 24 * 60 * 60) {
        Task {
            let cutoffDate = Date().addingTimeInterval(-timeInterval)

            do {
                let interviewDirs = try fileManager.contentsOfDirectory(
                    at: interviewDirectory,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: .skipsHiddenFiles
                )

                for interviewDir in interviewDirs {
                    let audioFiles = try fileManager.contentsOfDirectory(
                        at: interviewDir,
                        includingPropertiesForKeys: [.creationDateKey],
                        options: .skipsHiddenFiles
                    )

                    for audioFile in audioFiles {
                        if let attributes = try? fileManager.attributesOfItem(atPath: audioFile.path),
                           let creationDate = attributes[.creationDate] as? Date,
                           creationDate < cutoffDate {

                            try? fileManager.removeItem(at: audioFile)
                            print("Cleaned up old audio file: \(audioFile.lastPathComponent)")
                        }
                    }
                }

                // Reload segments after cleanup
                loadAvailableSegments()

            } catch {
                print("Failed to cleanup old audio files: \(error)")
            }
        }
    }

    func getDiskUsage() -> (audioSize: Int64, totalFiles: Int) {
        var totalSize: Int64 = 0
        var fileCount = 0

        let enumerator = fileManager.enumerator(at: audioDirectory, includingPropertiesForKeys: [.fileSizeKey])

        while let url = enumerator?.nextObject() as? URL {
            if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
                fileCount += 1
            }
        }

        return (totalSize, fileCount)
    }

    // MARK: - Export Directory

    func getExportDirectory() -> URL {
        return audioDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    func generateExportURL(for projectName: String) -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let fileName = "\(projectName)_\(timestamp).m4a"
        return getExportDirectory().appendingPathComponent(fileName)
    }

    // MARK: - File Validation

    func validateAudioFile(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }

        let asset = AVAsset(url: url)
        return asset.isReadable && asset.duration.seconds > 0
    }

    func getAudioDuration(for url: URL) async -> TimeInterval {
        let asset = AVAsset(url: url)

        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            print("Failed to get audio duration: \(error)")
            return 0
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension LocalAudioManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.errorMessage = "Recording finished with error"
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.errorMessage = "Recording error: \(error?.localizedDescription ?? "Unknown error")"
            self.isRecording = false
        }
    }
}

// MARK: - Utility Extensions

extension LocalAudioManager {
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}