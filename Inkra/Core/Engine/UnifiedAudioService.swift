import Foundation
import AVFoundation
import Combine

@MainActor
class UnifiedAudioService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var audioLevel: Float = 0.0
    
    // MARK: - Publishers
    
    let audioLevelPublisher = PassthroughSubject<Float, Never>()
    let silenceDetectedPublisher = PassthroughSubject<Void, Never>()
    let playbackFinishedPublisher = PassthroughSubject<Void, Never>()
    
    // MARK: - Audio Components
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayer?
    private var audioRecorder: AVAudioRecorder?
    private var streamPlayer: AVPlayer?
    private var playerObserver: Any?
    
    // MARK: - Public Access
    
    var currentAudioRecorder: AVAudioRecorder? {
        return audioRecorder
    }
    
    // MARK: - Recording Properties
    
    private var recordingURL: URL?
    private var recordingSession: AVAudioSession?
    
    // MARK: - Silence Detection (Removed - using SilenceDetectionService)
    // Simplified: UnifiedAudioService focuses on audio I/O only
    
    // MARK: - Level Monitoring
    
    private var levelTimer: Timer?
    private var levelResetTimer: Timer?  // Fallback timer to reset audio levels
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    func initialize() async throws {
        do {
            recordingSession = AVAudioSession.sharedInstance()
            try recordingSession?.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try recordingSession?.setActive(true)
            
            audioEngine = AVAudioEngine()
            
            print("[AudioService] Initialized successfully")
        } catch {
            print("[AudioService] Initialization failed: \(error)")
            throw AudioServiceError.initializationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Playback Methods
    
    func streamAudio(from url: URL) async throws {
        await stopAllPlayback()
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    // Create AVPlayer for streaming
                    let playerItem = AVPlayerItem(url: url)
                    streamPlayer = AVPlayer(playerItem: playerItem)
                    
                    // Setup completion observer
                    playerObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: playerItem,
                        queue: .main
                    ) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            self?.handlePlaybackFinished()
                            continuation.resume()
                        }
                    }
                    
                    // Start playback
                    isPlaying = true
                    streamPlayer?.play()
                    
                    print("[AudioService] Started streaming from: \(url)")
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func playText(_ text: String) async throws {
        // Fallback TTS implementation using AVSpeechSynthesizer
        await stopAllPlayback()
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let synthesizer = AVSpeechSynthesizer()
                let utterance = AVSpeechUtterance(string: text)
                utterance.rate = 0.5
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                
                isPlaying = true
                
                synthesizer.speak(utterance)
                
                // Simple completion after estimated duration
                let estimatedDuration = Double(text.count) * 0.06
                Task {
                    try await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1_000_000_000))
                    await MainActor.run {
                        self.handlePlaybackFinished()
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    func playLocalFile(_ url: URL) async throws {
        await stopAllPlayback()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            isPlaying = true
            audioPlayer?.play()
            
            print("[AudioService] Playing local file: \(url)")
            
        } catch {
            throw AudioServiceError.playbackFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Recording Methods
    
    func startRecording() async throws {
        await stopRecording()
        
        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "interview_\(Date().timeIntervalSince1970).m4a"
        recordingURL = documentsPath.appendingPathComponent(fileName)
        
        guard let recordingURL = recordingURL else {
            throw AudioServiceError.recordingFailed("Failed to create recording URL")
        }
        
        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            isRecording = true
            audioRecorder?.record()
            
            startLevelMonitoring()
            
            print("[AudioService] Started recording to: \(recordingURL)")
            
        } catch {
            throw AudioServiceError.recordingFailed(error.localizedDescription)
        }
    }
    
    @discardableResult
    func stopRecording() async -> URL? {
        print("[UnifiedAudioService] 🔴 Stopping recording - isRecording: \(isRecording), audioLevel: \(audioLevel)")
        guard isRecording, let recorder = audioRecorder else { 
            print("[UnifiedAudioService] ⚠️ stopRecording called but not recording")
            return nil 
        }
        
        await stopLevelMonitoring()
        // stopSilenceDetection() - removed during refactor
        
        recorder.stop()
        isRecording = false
        
        let url = recordingURL
        audioRecorder = nil
        recordingURL = nil
        
        print("[AudioService] Stopped recording. File saved to: \(String(describing: url))")
        
        return url
    }
    
    // MARK: - Control Methods
    
    func pauseAll() async {
        streamPlayer?.pause()
        audioPlayer?.pause()
        
        if isRecording {
            audioRecorder?.pause()
            // Stop level monitoring when pausing to prevent unnecessary timer calls
            await stopLevelMonitoring()
        }
        
        isPlaying = false
    }
    
    func resumeAll() async {
        if let player = streamPlayer {
            player.play()
            isPlaying = true
        } else if let player = audioPlayer {
            player.play()
            isPlaying = true
        }
        
        if let recorder = audioRecorder {
            recorder.record()
            isRecording = true
            // Restart level monitoring when resuming recording
            startLevelMonitoring()
        }
    }
    
    func stopAllPlayback() async {
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
        
        streamPlayer?.pause()
        streamPlayer = nil
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        isPlaying = false
    }
    
    // MARK: - Silence Detection (Removed)
    // Use SilenceDetectionService instead - UnifiedAudioService focuses on audio I/O only
    
    // MARK: - Level Monitoring
    
    private func startLevelMonitoring() {
        stopLevelMonitoring()
        
        print("[UnifiedAudioService] 🎧 Starting audio level monitoring")
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAudioLevels()
            }
        }
    }
    
    @MainActor
    private func stopLevelMonitoring() {
        print("[UnifiedAudioService] 🛑 Stopping audio level monitoring - audioLevel: \(audioLevel)")
        
        // Cancel any existing timers
        levelTimer?.invalidate()
        levelTimer = nil
        levelResetTimer?.invalidate()
        levelResetTimer = nil
        
        // Immediately reset audio level
        audioLevel = 0.0
        audioLevelPublisher.send(0.0)
        print("[UnifiedAudioService] ✅ Audio level reset to 0.0")
        
        // Add fallback mechanism: if audio level doesn't stay at 0 for some reason,
        // force it back to 0 after a short delay
        levelResetTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                if let strongSelf = self, strongSelf.audioLevel > 0.0 {
                    print("[UnifiedAudioService] ⚠️ Fallback: Force resetting audio level from \(strongSelf.audioLevel) to 0.0")
                    strongSelf.audioLevel = 0.0
                    strongSelf.audioLevelPublisher.send(0.0)
                }
            }
        }
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            print("[UnifiedAudioService] ⚠️ updateAudioLevels called but no recording - recorder: \(audioRecorder != nil ? "exists" : "nil"), isRecording: \(isRecording)")
            return
        }
        
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        
        // Normalize level to 0-1 range
        let normalizedLevel = max(0, min(1, (level + 60) / 60))
        
        // Debug logging for audio levels
        if normalizedLevel > 0.1 {
            print("[UnifiedAudioService] 🎤 Audio detected - raw: \(level), normalized: \(normalizedLevel)")
        }
        
        audioLevel = normalizedLevel
        audioLevelPublisher.send(normalizedLevel)
        
        // Silence detection removed - handled by SilenceDetectionService
        // This service focuses on audio level monitoring only
    }
    
    // Silence timer methods removed - use SilenceDetectionService instead
    
    private func handlePlaybackFinished() {
        isPlaying = false
        playbackFinishedPublisher.send()
        print("[AudioService] Playback finished")
    }
    
    func preloadAudio(from url: URL) async throws {
        // Preload audio in background without playing
        let playerItem = AVPlayerItem(url: url)
        
        // Store in cache for later use
        // This is a simplified implementation - could be enhanced with proper caching
        print("[UnifiedAudioService] Preloaded audio from: \(url)")
    }
    
    // MARK: - Cleanup
    
    func cleanup() async {
        print("[UnifiedAudioService] 🧹 Starting cleanup - audioLevel: \(audioLevel), isRecording: \(isRecording)")
        await stopAllPlayback()
        await stopRecording()
        await stopLevelMonitoring()
        // Silence detection cleanup removed - handled by SilenceDetectionService
        
        try? recordingSession?.setActive(false)
        recordingSession = nil
        audioEngine = nil
        
        print("[UnifiedAudioService] ✅ Cleanup complete - audioLevel should be 0.0: \(audioLevel)")
    }
}

// MARK: - AVAudioPlayerDelegate

extension UnifiedAudioService: AVAudioPlayerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            handlePlaybackFinished()
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension UnifiedAudioService: AVAudioRecorderDelegate {
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                print("[AudioService] Recording finished successfully")
            } else {
                print("[AudioService] Recording finished with error")
            }
        }
    }
}

// MARK: - Error Types

enum AudioServiceError: LocalizedError {
    case initializationFailed(String)
    case playbackFailed(String)
    case recordingFailed(String)
    case streamingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Audio initialization failed: \(message)"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .streamingFailed(let message):
            return "Streaming failed: \(message)"
        }
    }
}