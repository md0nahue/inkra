import Foundation
import AVFoundation
import Combine

@MainActor
class AudioStitchingService: ObservableObject {
    static let shared = AudioStitchingService()

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var exportProgress: Double = 0
    @Published var errorMessage: String?
    @Published var lastExportURL: URL?

    // MARK: - Private Properties

    private var exportSession: AVAssetExportSession?
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Export Quality Options

    enum ExportQuality: CaseIterable {
        case low
        case medium
        case high
        case lossless

        var presetName: String {
            switch self {
            case .low:
                return AVAssetExportPresetLowQuality
            case .medium:
                return AVAssetExportPresetMediumQuality
            case .high:
                return AVAssetExportPresetHighQuality
            case .lossless:
                return AVAssetExportPresetAppleLossless
            }
        }

        var description: String {
            switch self {
            case .low:
                return "Low Quality (64 kbps)"
            case .medium:
                return "Medium Quality (128 kbps)"
            case .high:
                return "High Quality (256 kbps)"
            case .lossless:
                return "Lossless (ALAC)"
            }
        }
    }

    // MARK: - Export Configuration

    struct ExportConfiguration {
        let quality: ExportQuality
        let fadeInDuration: TimeInterval
        let fadeOutDuration: TimeInterval
        let silenceBetweenSegments: TimeInterval
        let includeQuestionMarkers: Bool
        let normalizeAudio: Bool

        static let `default` = ExportConfiguration(
            quality: .high,
            fadeInDuration: 0.5,
            fadeOutDuration: 0.5,
            silenceBetweenSegments: 1.0,
            includeQuestionMarkers: false,
            normalizeAudio: true
        )
    }

    // MARK: - Main Stitching Method

    func stitchAudioSegments(
        segments: [LocalAudioSegment],
        outputURL: URL,
        configuration: ExportConfiguration = .default,
        projectTitle: String? = nil
    ) async -> Bool {

        guard !segments.isEmpty else {
            errorMessage = "No audio segments provided"
            return false
        }

        // Validate all segments have valid URLs
        let validSegments = segments.compactMap { segment -> LocalAudioSegment? in
            guard let url = segment.localFileURL,
                  FileManager.default.fileExists(atPath: url.path) else {
                print("Warning: Skipping invalid segment: \(segment.fileName)")
                return nil
            }
            return segment
        }

        guard !validSegments.isEmpty else {
            errorMessage = "No valid audio segments found"
            return false
        }

        isProcessing = true
        exportProgress = 0
        errorMessage = nil

        do {
            // Create composition
            let composition = AVMutableComposition()
            guard let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw AudioStitchingError.compositionCreationFailed
            }

            var currentTime = CMTime.zero
            let silenceDuration = CMTime(seconds: configuration.silenceBetweenSegments, preferredTimescale: 44100)

            // Add each segment to the composition
            for (index, segment) in validSegments.enumerated() {
                guard let segmentURL = segment.localFileURL else { continue }

                let asset = AVAsset(url: segmentURL)

                // Validate asset
                guard try await asset.load(.isReadable),
                      let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                    print("Warning: Could not load track for segment: \(segment.fileName)")
                    continue
                }

                // Insert the audio segment
                let duration = try await asset.load(.duration)
                let timeRange = CMTimeRange(start: .zero, duration: duration)

                try audioTrack.insertTimeRange(
                    timeRange,
                    of: assetTrack,
                    at: currentTime
                )

                // Update progress
                exportProgress = Double(index + 1) / Double(validSegments.count + 1) * 0.7

                currentTime = CMTimeAdd(currentTime, duration)

                // Add silence between segments (except for the last one)
                if index < validSegments.count - 1 {
                    currentTime = CMTimeAdd(currentTime, silenceDuration)
                }
            }

            // Apply audio enhancements
            if configuration.normalizeAudio || configuration.fadeInDuration > 0 || configuration.fadeOutDuration > 0 {
                composition = try await applyAudioEnhancements(
                    to: composition,
                    configuration: configuration
                )
            }

            // Export the composition
            let success = await exportComposition(
                composition,
                to: outputURL,
                quality: configuration.quality,
                projectTitle: projectTitle
            )

            if success {
                lastExportURL = outputURL
            }

            isProcessing = false
            return success

        } catch {
            isProcessing = false
            errorMessage = "Failed to stitch audio: \(error.localizedDescription)"
            print("Audio stitching error: \(error)")
            return false
        }
    }

    // MARK: - Audio Enhancements

    private func applyAudioEnhancements(
        to composition: AVMutableComposition,
        configuration: ExportConfiguration
    ) async throws -> AVMutableComposition {

        guard let audioTrack = composition.tracks(withMediaType: .audio).first as? AVMutableCompositionTrack else {
            return composition
        }

        let audioMix = AVMutableAudioMix()
        let audioMixParams = AVMutableAudioMixInputParameters(track: audioTrack)

        // Apply fade in
        if configuration.fadeInDuration > 0 {
            audioMixParams.setVolumeRamp(
                fromStartVolume: 0.0,
                toEndVolume: 1.0,
                timeRange: CMTimeRange(
                    start: .zero,
                    duration: CMTime(seconds: configuration.fadeInDuration, preferredTimescale: 44100)
                )
            )
        }

        // Apply fade out
        if configuration.fadeOutDuration > 0 {
            let totalDuration = composition.duration
            let fadeOutStart = CMTimeSubtract(totalDuration, CMTime(seconds: configuration.fadeOutDuration, preferredTimescale: 44100))

            audioMixParams.setVolumeRamp(
                fromStartVolume: 1.0,
                toEndVolume: 0.0,
                timeRange: CMTimeRange(
                    start: fadeOutStart,
                    duration: CMTime(seconds: configuration.fadeOutDuration, preferredTimescale: 44100)
                )
            )
        }

        audioMix.inputParameters = [audioMixParams]

        // Note: For normalization, we'd need to use AVAudioEngine or a more complex processing pipeline
        // This would be implemented in a future version

        return composition
    }

    // MARK: - Export Composition

    private func exportComposition(
        _ composition: AVComposition,
        to outputURL: URL,
        quality: ExportQuality,
        projectTitle: String?
    ) async -> Bool {

        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: quality.presetName
        ) else {
            errorMessage = "Failed to create export session"
            return false
        }

        self.exportSession = exportSession

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Set metadata
        if let projectTitle = projectTitle {
            exportSession.metadata = [
                AVMutableMetadataItem.createMetadataItem(
                    identifier: .commonIdentifierTitle,
                    value: projectTitle
                ),
                AVMutableMetadataItem.createMetadataItem(
                    identifier: .commonIdentifierCreator,
                    value: "Inkra"
                ),
                AVMutableMetadataItem.createMetadataItem(
                    identifier: .commonIdentifierCreationDate,
                    value: Date()
                )
            ]
        }

        // Start export with progress monitoring
        return await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                Task { @MainActor in
                    switch exportSession.status {
                    case .completed:
                        self.exportProgress = 1.0
                        continuation.resume(returning: true)
                    case .failed:
                        self.errorMessage = "Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")"
                        continuation.resume(returning: false)
                    case .cancelled:
                        self.errorMessage = "Export was cancelled"
                        continuation.resume(returning: false)
                    default:
                        self.errorMessage = "Export finished with unexpected status: \(exportSession.status)"
                        continuation.resume(returning: false)
                    }
                }
            }

            // Monitor progress
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                Task { @MainActor in
                    if self.exportSession?.status == .exporting {
                        // Combine composition progress (70%) and export progress (30%)
                        let exportProgress = 0.7 + (Double(exportSession.progress) * 0.3)
                        self.exportProgress = min(exportProgress, 1.0)
                    } else {
                        timer.invalidate()
                    }
                }
            }

            // Cleanup timer when export completes
            Task {
                _ = await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    continuation.resume()
                }
                progressTimer.invalidate()
            }
        }
    }

    // MARK: - Utility Methods

    func cancelExport() {
        exportSession?.cancelExport()
        exportSession = nil
        isProcessing = false
        errorMessage = "Export cancelled"
    }

    func estimateExportFileSize(
        segments: [LocalAudioSegment],
        quality: ExportQuality
    ) async -> Int64 {

        let totalDuration = segments.reduce(0) { $0 + $1.duration }

        // Rough estimates based on quality
        let bitRateKbps: Double
        switch quality {
        case .low: bitRateKbps = 64
        case .medium: bitRateKbps = 128
        case .high: bitRateKbps = 256
        case .lossless: bitRateKbps = 1411 // CD quality
        }

        // File size = (bitrate * duration) / 8 / 1024 (convert to KB)
        let estimatedSizeKB = (bitRateKbps * totalDuration) / 8
        return Int64(estimatedSizeKB * 1024) // Convert to bytes
    }

    func validateSegmentsForExport(_ segments: [LocalAudioSegment]) -> [ValidationError] {
        var errors: [ValidationError] = []

        for (index, segment) in segments.enumerated() {
            guard let url = segment.localFileURL else {
                errors.append(.missingFile(segmentIndex: index, fileName: segment.fileName))
                continue
            }

            guard FileManager.default.fileExists(atPath: url.path) else {
                errors.append(.fileNotFound(segmentIndex: index, fileName: segment.fileName))
                continue
            }

            if segment.duration <= 0 {
                errors.append(.invalidDuration(segmentIndex: index, fileName: segment.fileName))
            }
        }

        return errors
    }

    // MARK: - Preview Generation

    func generatePreview(
        segments: [LocalAudioSegment],
        previewDuration: TimeInterval = 30.0
    ) async -> URL? {

        guard !segments.isEmpty else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("preview_\(UUID().uuidString).m4a")

        // Take first few segments that fit within preview duration
        var previewSegments: [LocalAudioSegment] = []
        var totalDuration: TimeInterval = 0

        for segment in segments {
            if totalDuration + segment.duration <= previewDuration {
                previewSegments.append(segment)
                totalDuration += segment.duration
            } else {
                break
            }
        }

        let config = ExportConfiguration(
            quality: .medium,
            fadeInDuration: 0.5,
            fadeOutDuration: 0.5,
            silenceBetweenSegments: 0.5,
            includeQuestionMarkers: false,
            normalizeAudio: false
        )

        let success = await stitchAudioSegments(
            segments: previewSegments,
            outputURL: tempURL,
            configuration: config
        )

        return success ? tempURL : nil
    }
}

// MARK: - Error Types

enum AudioStitchingError: LocalizedError {
    case compositionCreationFailed
    case trackCreationFailed
    case assetLoadingFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .compositionCreationFailed:
            return "Failed to create audio composition"
        case .trackCreationFailed:
            return "Failed to create audio track"
        case .assetLoadingFailed(let asset):
            return "Failed to load asset: \(asset)"
        case .exportFailed(let error):
            return "Export failed: \(error)"
        }
    }
}

enum ValidationError: LocalizedError {
    case missingFile(segmentIndex: Int, fileName: String)
    case fileNotFound(segmentIndex: Int, fileName: String)
    case invalidDuration(segmentIndex: Int, fileName: String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let index, let fileName):
            return "Segment \(index + 1) (\(fileName)) is missing file URL"
        case .fileNotFound(let index, let fileName):
            return "Segment \(index + 1) (\(fileName)) file not found"
        case .invalidDuration(let index, let fileName):
            return "Segment \(index + 1) (\(fileName)) has invalid duration"
        }
    }
}

// MARK: - AVMetadataItem Extension

extension AVMutableMetadataItem {
    static func createMetadataItem(identifier: AVMetadataIdentifier, value: Any) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        item.extendedLanguageTag = "und"
        return item
    }
}