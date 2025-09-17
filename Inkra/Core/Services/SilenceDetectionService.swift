import Foundation
import AVFoundation
import Combine

/// Gold Standard Silence Detection Service
/// Single source of truth for all silence detection logic
@MainActor
class SilenceDetectionService: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var isSpeechDetected: Bool = false
    @Published private(set) var isCountdownActive: Bool = false
    @Published private(set) var countdownSeconds: Int = 0
    
    // MARK: - Configuration
    
    private let speechThreshold: Float = -30.0     // dB threshold for speech detection
    private let silenceDuration: TimeInterval = 3.0   // seconds of silence before countdown
    private let countdownDuration: TimeInterval = 3.0  // countdown duration in seconds
    private let levelUpdateInterval: TimeInterval = 0.05  // 50ms updates
    
    // MARK: - State Management
    
    private var isEnabled: Bool = false
    private var lastSpeechTime: Date = Date()
    private var audioRecorder: AVAudioRecorder?
    
    // MARK: - Timers
    
    private var levelTimer: Timer?
    private var silenceTimer: Timer?
    private var countdownTimer: Timer?
    
    // MARK: - Publishers
    
    let speechDetectedPublisher = PassthroughSubject<Void, Never>()
    let silenceDetectedPublisher = PassthroughSubject<Void, Never>()
    let countdownStartedPublisher = PassthroughSubject<Void, Never>()
    let countdownStoppedPublisher = PassthroughSubject<Void, Never>()
    
    // MARK: - Debug Logging
    
    private let debugEnabled = true
    
    private func debugLog(_ message: String, category: String = "SILENCE") {
        guard debugEnabled else { return }
        print("🎯 [\(category)] \(message)")
    }
    
    // MARK: - Public Interface
    
    /// Enable silence detection with the provided audio recorder
    func enableSilenceDetection(with recorder: AVAudioRecorder) {
        debugLog("Enabling silence detection")
        debugLog("  - Threshold: \(speechThreshold) dB", category: "CONFIG")
        debugLog("  - Silence duration: \(silenceDuration)s", category: "CONFIG")
        debugLog("  - Countdown duration: \(countdownDuration)s", category: "CONFIG")
        debugLog("  - Update interval: \(levelUpdateInterval)s", category: "CONFIG")
        
        audioRecorder = recorder
        isEnabled = true
        lastSpeechTime = Date()
        
        // Reset state
        audioLevel = 0.0
        isSpeechDetected = false
        isCountdownActive = false
        countdownSeconds = 0
        
        startLevelMonitoring()
        debugLog("✅ Silence detection enabled")
    }
    
    /// Disable silence detection and clean up
    func disableSilenceDetection() {
        debugLog("Disabling silence detection")
        
        isEnabled = false
        stopAllTimers()
        
        // Reset state
        audioLevel = 0.0
        isSpeechDetected = false
        isCountdownActive = false
        countdownSeconds = 0
        
        audioRecorder = nil
        debugLog("✅ Silence detection disabled")
    }
    
    /// Reset detection state (e.g., when user manually advances)
    func resetDetection() {
        debugLog("Resetting detection state")
        
        lastSpeechTime = Date()
        stopCountdown()
        stopSilenceTimer()
        
        if isSpeechDetected {
            debugLog("  - Speech state was active, keeping active")
        }
    }
    
    /// Force trigger silence detection (for testing)
    func forceTriggerSilence() {
        debugLog("Force triggering silence detection", category: "FORCE")
        handleSilenceThresholdReached()
    }
    
    // MARK: - Private Implementation
    
    private func startLevelMonitoring() {
        stopLevelMonitoring()
        
        debugLog("Starting audio level monitoring", category: "MONITOR")
        
        levelTimer = Timer.scheduledTimer(withTimeInterval: levelUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAudioLevel()
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        debugLog("Stopped audio level monitoring", category: "MONITOR")
    }
    
    private func updateAudioLevel() {
        guard isEnabled, let recorder = audioRecorder, recorder.isRecording else {
            // Set level to 0 if not recording
            if audioLevel != 0.0 {
                audioLevel = 0.0
                debugLog("Audio level reset to 0 (not recording)", category: "LEVEL")
            }
            return
        }
        
        recorder.updateMeters()
        let rawLevel = recorder.averagePower(forChannel: 0)
        
        // Normalize to 0-1 range for UI display
        let normalizedLevel = max(0.0, min(1.0, (rawLevel + 60.0) / 60.0))
        audioLevel = normalizedLevel
        
        // Speech detection logic
        let currentlyDetected = rawLevel > speechThreshold
        
        if currentlyDetected {
            handleSpeechDetected(rawLevel: rawLevel)
        } else {
            handleNoSpeechDetected(rawLevel: rawLevel)
        }
    }
    
    private func handleSpeechDetected(rawLevel: Float) {
        let wasDetected = isSpeechDetected
        
        // Update speech state
        isSpeechDetected = true
        lastSpeechTime = Date()
        
        // Stop any silence-related timers
        stopSilenceTimer()
        stopCountdown()
        
        // Log speech detection
        if !wasDetected {
            debugLog("🎤 SPEECH DETECTED: \(String(format: "%.1f", rawLevel)) dB (threshold: \(String(format: "%.1f", speechThreshold)) dB)", category: "SPEECH")
            speechDetectedPublisher.send()
        }
    }
    
    private func handleNoSpeechDetected(rawLevel: Float) {
        let timeSinceLastSpeech = Date().timeIntervalSince(lastSpeechTime)
        
        // If we were detecting speech and now we're not, start silence monitoring
        if isSpeechDetected {
            debugLog("🔇 SPEECH ENDED: \(String(format: "%.1f", rawLevel)) dB, starting silence timer", category: "SPEECH")
            isSpeechDetected = false
            startSilenceTimer()
        }
        // If silence timer isn't running and we've been silent, start it
        else if silenceTimer == nil && timeSinceLastSpeech > 0.1 {
            debugLog("🔇 CONTINUED SILENCE: \(String(format: "%.1f", rawLevel)) dB (\(String(format: "%.1f", timeSinceLastSpeech))s)", category: "SILENCE")
            startSilenceTimer()
        }
    }
    
    private func startSilenceTimer() {
        stopSilenceTimer()
        
        debugLog("⏱️ Starting silence timer (\(silenceDuration)s)", category: "TIMER")
        
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSilenceThresholdReached()
            }
        }
    }
    
    private func stopSilenceTimer() {
        if silenceTimer != nil {
            silenceTimer?.invalidate()
            silenceTimer = nil
            debugLog("⏹️ Stopped silence timer", category: "TIMER")
        }
    }
    
    private func handleSilenceThresholdReached() {
        debugLog("⏰ Silence threshold reached, starting countdown", category: "COUNTDOWN")
        startCountdown()
    }
    
    private func startCountdown() {
        stopCountdown()
        
        isCountdownActive = true
        countdownSeconds = Int(countdownDuration)
        
        debugLog("⏱️ Starting countdown: \(countdownSeconds) seconds", category: "COUNTDOWN")
        countdownStartedPublisher.send()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                self.countdownSeconds -= 1
                self.debugLog("⏰ Countdown: \(self.countdownSeconds)", category: "COUNTDOWN")
                
                if self.countdownSeconds <= 0 {
                    timer.invalidate()
                    self.handleCountdownFinished()
                }
            }
        }
    }
    
    private func stopCountdown() {
        if isCountdownActive {
            debugLog("⏹️ Stopping countdown", category: "COUNTDOWN")
            
            countdownTimer?.invalidate()
            countdownTimer = nil
            isCountdownActive = false
            countdownSeconds = 0
            
            countdownStoppedPublisher.send()
        }
    }
    
    private func handleCountdownFinished() {
        debugLog("🚨 COUNTDOWN FINISHED - Silence detected!", category: "RESULT")
        
        isCountdownActive = false
        countdownSeconds = 0
        
        silenceDetectedPublisher.send()
    }
    
    private func stopAllTimers() {
        stopLevelMonitoring()
        stopSilenceTimer()
        stopCountdown()
        debugLog("🛑 All timers stopped", category: "TIMER")
    }
    
    // MARK: - Cleanup
    
    deinit {
        Task { @MainActor in
            stopAllTimers()
            debugLog("🧹 SilenceDetectionService deinitialized")
        }
    }
}

// MARK: - Configuration Extension

extension SilenceDetectionService {
    
    /// Get current configuration for debugging
    var debugConfiguration: [String: Any] {
        return [
            "speechThreshold": speechThreshold,
            "silenceDuration": silenceDuration,
            "countdownDuration": countdownDuration,
            "levelUpdateInterval": levelUpdateInterval,
            "isEnabled": isEnabled,
            "audioLevel": audioLevel,
            "isSpeechDetected": isSpeechDetected,
            "isCountdownActive": isCountdownActive,
            "countdownSeconds": countdownSeconds
        ]
    }
    
    /// Print comprehensive debug status
    func printDebugStatus() {
        debugLog("=== SILENCE DETECTION STATUS ===", category: "DEBUG")
        debugLog("  Enabled: \(isEnabled)", category: "DEBUG")
        debugLog("  Audio Level: \(String(format: "%.3f", audioLevel))", category: "DEBUG")
        debugLog("  Speech Detected: \(isSpeechDetected)", category: "DEBUG")
        debugLog("  Countdown Active: \(isCountdownActive)", category: "DEBUG")
        debugLog("  Countdown Seconds: \(countdownSeconds)", category: "DEBUG")
        debugLog("  Has Recorder: \(audioRecorder != nil)", category: "DEBUG")
        debugLog("  Timers: Level=\(levelTimer != nil), Silence=\(silenceTimer != nil), Countdown=\(countdownTimer != nil)", category: "DEBUG")
        debugLog("================================", category: "DEBUG")
    }
}