import Foundation
import AVFoundation
import Combine

@available(iOS 15.0, macOS 10.15, *)
@MainActor
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentAmplitude: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var permissionGranted = false
    @Published var errorMessage: String?
    
    // Store raw amplitude for speech detection comparisons
    private var rawAmplitude: Float = -160.0
    
    // Simplified speech detection - delegated to SilenceDetectionService
    @Published var isSpeechDetected = false
    @Published var showingSilenceCountdown = false
    @Published var silenceCountdown: Int = 0
    
    // Callbacks for speech interview mode
    var onSpeechDetected: (() -> Void)?
    var onSilenceDetected: (() -> Void)?
    var onCountdownStarted: (() -> Void)?
    var onCountdownStopped: (() -> Void)?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    #if canImport(UIKit)
    private var recordingSession: AVAudioSession?
    #endif
    private var timer: Timer?
    private var amplitudeTimer: Timer?
    private var recordingURL: URL?
    
    // Synchronization properties to prevent race conditions
    private var isInitializingRecording = false
    private var sessionConfigured = false
    
    override init() {
        super.init()
        // Only check permission status in init - defer audio session setup
        checkPermissionStatus()
    }
    
    deinit {
        // Clean up synchronously without calling @MainActor methods
        audioRecorder?.stop()
        audioPlayer?.stop()
        timer?.invalidate()
        amplitudeTimer?.invalidate()
    }
    
    private func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            // ENHANCED AUDIO SESSION SETUP with better error handling
            guard let session = recordingSession else {
                throw NSError(domain: "AudioRecorder", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to get shared audio session"
                ])
            }
            
            // First, deactivate any existing session to ensure clean state
            try? session.setActive(false)
            
            // Configure the session with comprehensive options
            try session.setCategory(.playAndRecord, 
                                  mode: .default, 
                                  options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            
            // Set preferred audio properties for stability
            try session.setPreferredSampleRate(44100.0)
            try session.setPreferredInputNumberOfChannels(1)
            try session.setPreferredIOBufferDuration(0.02) // 20ms buffer for responsiveness
            
            // Activate the session
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Quick validation
            let inputAvailable = session.isInputAvailable
            let inputChannels = session.inputNumberOfChannels
            let sampleRate = session.sampleRate
            
            if inputAvailable && inputChannels > 0 && sampleRate > 0 {
                sessionConfigured = true
            } else {
                throw NSError(domain: "AudioRecorder", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Audio session validation failed - input not ready"
                ])
            }
            
        } catch {
            sessionConfigured = false
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
            print("❌ Audio session setup error: \(error)")
        }
    }
    
    func checkPermissionStatus() {
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            permissionGranted = (status == .granted)
            
            if status == .denied {
                errorMessage = "Microphone permission denied. Please enable it in Settings."
            }
        } else {
            let status = AVAudioSession.sharedInstance().recordPermission
            permissionGranted = (status == .granted)
            
            if status == .denied {
                errorMessage = "Microphone permission denied. Please enable it in Settings."
            }
        }
    }
    
    func requestPermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                    if !granted {
                        self.errorMessage = "Microphone permission denied. Please enable it in Settings."
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                    if !granted {
                        self.errorMessage = "Microphone permission denied. Please enable it in Settings."
                    }
                }
            }
        }
    }
    
    func startRecording() async -> URL? {
        print("\n🎤 AUDIO RECORDER START DEBUG")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Simplified recording start without AI voice conflict detection
        
        print("🔍 PRE-FLIGHT CHECKS:")
        print("   - isInitializingRecording: \(isInitializingRecording)")
        print("   - isRecording: \(isRecording)")
        print("   - permissionGranted: \(permissionGranted)")
        print("   - sessionConfigured: \(sessionConfigured)")
        print("   - Speech detection simplified")
        
        // Prevent concurrent initialization attempts
        guard !isInitializingRecording else {
            print("⚠️ CONCURRENT INIT DETECTED - Recording initialization already in progress, waiting...")
            // Wait for current initialization to complete
            for attempt in 0..<10 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                print("   - Waiting attempt \(attempt + 1)/10")
                if !isInitializingRecording {
                    print("   ✅ Concurrent initialization completed")
                    break
                }
            }
            return recordingURL
        }
        
        // Check permission status before proceeding
        print("\n🔐 PERMISSION CHECK:")
        checkPermissionStatus()
        print("   - Permission status after check: \(permissionGranted)")
        guard permissionGranted else {
            let error = "Microphone permission required. Please enable microphone access in Settings."
            print("❌ PERMISSION DENIED: \(error)")
            errorMessage = error
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            return nil
        }
        
        guard !isRecording else {
            print("⚠️ ALREADY RECORDING - returning existing URL: \(recordingURL?.path ?? "nil")")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            return recordingURL
        }
        
        print("\n🚀 STARTING RECORDING INITIALIZATION")
        isInitializingRecording = true
        defer { 
            isInitializingRecording = false 
            print("🏁 Recording initialization flag cleared")
        }
        
        // Fast audio session setup
        if !sessionConfigured {
            setupAudioSession()
        }
        
        // Final validation before proceeding
        guard sessionConfigured else {
            let error = "Audio session configuration failed"
            print("❌ FATAL: Audio session setup FAILED")
            errorMessage = error
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            return nil
        }
        
        print("✅ AUDIO SESSION READY - proceeding to recording setup")
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Re-configure audio session to ensure it's in the correct state
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            
            // Check if we need to request route change
            if !session.isInputAvailable {
                print("Input not available, requesting audio route...")
                try session.setPreferredInput(session.availableInputs?.first)
            }
            
            // Activate the session
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Quick validation
            let inputChannels = session.inputNumberOfChannels
            let inputAvailable = session.isInputAvailable
            
            if inputChannels == 0 || !inputAvailable {
                let errorMsg = "Audio input not available. Channels: \(inputChannels), Available: \(inputAvailable)"
                errorMessage = errorMsg
                try? session.setActive(false)
                return nil
            }
            
            // Simple recorder settings
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Prepare and start recording
            guard audioRecorder?.prepareToRecord() == true else {
                errorMessage = "Failed to prepare audio recorder"
                try? session.setActive(false)
                return nil
            }
            
            guard audioRecorder?.record() == true else {
                errorMessage = "Failed to start audio recording"
                try? session.setActive(false)
                return nil
            }
            
            recordingURL = audioFilename
            isRecording = true
            recordingDuration = 0.0
            
            startTimers()
            print("\n✅ RECORDING STARTED SUCCESSFULLY")
            print("   - File: \(audioFilename.path)")
            print("   - Channels: 1")
            print("   - Sample Rate: 44100Hz")
            print("   - isRecording: \(isRecording)")
            print("   - Timers started: true")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            
            return audioFilename
        } catch {
            let errorMsg = "Could not start recording: \(error.localizedDescription)"
            print("\n❌ RECORDING START FAILED")
            print("   - Error: \(error)")
            print("   - Error description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - Domain: \(nsError.domain)")
                print("   - Code: \(nsError.code)")
                print("   - UserInfo: \(nsError.userInfo)")
            }
            errorMessage = errorMsg
            try? AVAudioSession.sharedInstance().setActive(false)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            return nil
        }
    }
    
    func stopRecording() -> URL? {
        print("\n⏹️ STOP RECORDING DEBUG")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("   - isRecording: \(isRecording)")
        print("   - recordingURL: \(recordingURL?.path ?? "nil")")
        print("   - recordingDuration: \(recordingDuration)s")
        
        guard isRecording else { 
            print("⚠️ NOT RECORDING - returning existing URL")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            return recordingURL
        }
        
        print("   - Stopping audioRecorder...")
        audioRecorder?.stop()
        isRecording = false
        isInitializingRecording = false // Clear initialization flag if stuck
        
        print("   - Stopping timers...")
        stopTimers()
        print("   ✅ Recording stopped successfully")
        
        // Reset audio session to clean state
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            print("   - Deactivating audio session...")
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("   ✅ Audio session deactivated")
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        return recordingURL
    }
    
    func pauseRecording() {
        guard isRecording else { return }
        
        audioRecorder?.pause()
        stopTimers()
        print("Recording paused")
    }
    
    func resumeRecording() {
        guard !isRecording else { return }
        
        audioRecorder?.record()
        isRecording = true
        startTimers()
        print("Recording resumed")
    }
    
    func playRecording(from url: URL? = nil) {
        guard !isRecording else {
            let msg = "Cannot play while recording"
            print("AudioPlayback Error: \(msg)")
            errorMessage = msg
            return
        }
        
        // Use provided URL or fall back to recordingURL
        let urlToPlay = url ?? recordingURL
        
        guard let url = urlToPlay else {
            let msg = "No recording URL available to play"
            print("AudioPlayback Error: \(msg)")
            errorMessage = msg
            return
        }

        print("AudioPlayback: Attempting to play from URL: \(url.path)")
        
        // Check if file exists before attempting to play
        guard FileManager.default.fileExists(atPath: url.path) else {
            let msg = "Audio file does not exist at path: \(url.path)"
            print("AudioPlayback Error: \(msg)")
            errorMessage = msg
            return
        }
        
        do {
            // Ensure the audio session is active and set for playback.
            // It should be set to .playAndRecord already, but this is a good check.
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            print("AudioPlayback: Audio session configured for playback.")

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            
            print("AudioPlayback: AVAudioPlayer initialized successfully. Duration: \(audioPlayer?.duration ?? 0)s")
            
            if audioPlayer?.play() == true {
                isPlaying = true
                print("AudioPlayback: Playback started successfully.")
            } else {
                let msg = "audioPlayer.play() returned false."
                print("AudioPlayback Error: \(msg)")
                errorMessage = msg
            }
        } catch {
            let msg = "Could not initialize AVAudioPlayer: \(error.localizedDescription)"
            print("AudioPlayback Error: \(msg)")
            errorMessage = msg
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    func deleteRecording() {
        _ = stopRecording()
        stopPlayback()
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
            recordingDuration = 0.0
            currentAmplitude = 0.0
        }
    }
    
    private func startTimers() {
        // Use main queue timer for better performance and prevent async overhead
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let recorder = self.audioRecorder else { return }
                self.recordingDuration = recorder.currentTime
            }
        }
        
        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let amplitude = recorder.averagePower(forChannel: 0)
                
                // Store raw amplitude for speech detection comparisons
                self.rawAmplitude = amplitude
                
                // Enhanced dynamic range for better voice responsiveness
                // amplitude ranges from -160 dB (silence) to 0 dB (max)
                let normalizedAmplitude = max(0.0, (amplitude + 50.0) / 50.0) // Focus on -50dB to 0dB range for voice
                let voiceOptimizedAmplitude = pow(normalizedAmplitude, 0.3) // More sensitive power curve for speech
                self.currentAmplitude = Float(min(1.0, voiceOptimizedAmplitude * 1.5))
                
                // Note: Speech detection is now handled by SilenceDetectionService
            }
        }
    }
    
    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
        currentAmplitude = 0.0
        isSpeechDetected = false
        showingSilenceCountdown = false
        silenceCountdown = 0
    }
    
    // MARK: - Speech Detection (Simplified - using SilenceDetectionService)
    
    /// Update speech state from external SilenceDetectionService
    func updateSpeechState(detected: Bool) {
        let wasDetected = isSpeechDetected
        isSpeechDetected = detected
        
        if detected && !wasDetected {
            onSpeechDetected?()
        }
    }
    
    /// Update countdown state from external SilenceDetectionService  
    func updateCountdownState(active: Bool, seconds: Int) {
        showingSilenceCountdown = active
        silenceCountdown = seconds
        
        if active && !showingSilenceCountdown {
            onCountdownStarted?()
        } else if !active && showingSilenceCountdown {
            onCountdownStopped?()
        }
    }
    
    /// Handle silence detection from external service
    func handleSilenceDetection() {
        onSilenceDetected?()
    }
    
    func setSpeechDetectionCallbacks(
        onSpeech: @escaping () -> Void,
        onSilence: @escaping () -> Void,
        onCountdownStarted: (() -> Void)? = nil,
        onCountdownStopped: (() -> Void)? = nil
    ) {
        self.onSpeechDetected = onSpeech
        self.onSilenceDetected = onSilence
        self.onCountdownStarted = onCountdownStarted
        self.onCountdownStopped = onCountdownStopped
    }
    
    // Speech detection control methods removed - handled by SilenceDetectionService
    
    func getRecordingData() -> Data? {
        guard let url = recordingURL else { return nil }
        return try? Data(contentsOf: url)
    }
    
    func getRecordingDuration() -> TimeInterval {
        return recordingDuration
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func resetTimer() {
        recordingDuration = 0.0
    }
    
    // Call this method when experiencing audio issues to reset the session
    func resetAudioSession() async {
        // Stop any ongoing recording or playback
        if isRecording {
            _ = stopRecording()
        }
        if isPlaying {
            stopPlayback()
        }
        
        // Clear flags
        isInitializingRecording = false
        sessionConfigured = false
        
        // Reset the audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false)
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            
            // Reconfigure from scratch
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            sessionConfigured = true
            
            print("Audio session reset successfully")
            errorMessage = nil
        } catch {
            errorMessage = "Failed to reset audio session: \(error.localizedDescription)"
            print("Audio session reset error: \(error)")
        }
    }
    
    // Silence timer methods removed - handled by SilenceDetectionService
    
    // MARK: - AI Voice Coordination
    
    func setAIVoicePlayingStatus(_ isPlaying: Bool) {
        // This method is called by NativeVoiceService to coordinate between AI voice and recording
        // Currently not needed in simplified audio architecture, but kept for compatibility
        print("[AudioRecorder] 🎵 AI voice playing status: \(isPlaying)")
    }
}

@available(iOS 15.0, macOS 10.15, *)
extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            if !flag {
                self.errorMessage = "Recording failed"
            }
            self.isRecording = false
            self.stopTimers()
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async {
            self.errorMessage = "Recording error: \(error?.localizedDescription ?? "Unknown error")"
            self.isRecording = false
            self.stopTimers()
        }
    }
}

@available(iOS 15.0, macOS 10.15, *)
extension AudioRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.errorMessage = "Playback error: \(error?.localizedDescription ?? "Unknown error")"
            self.isPlaying = false
        }
    }
}