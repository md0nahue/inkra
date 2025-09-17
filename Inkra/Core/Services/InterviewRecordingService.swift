import Foundation
import Combine

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class InterviewRecordingService: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var userExplicitlyStoppedRecording = false
    
    let audioRecorder = AudioRecorder()
    
    private var stateService: InterviewStateService?
    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?
    
    init() {
        setupRecorderObservation()
    }
    
    func configure(with stateService: InterviewStateService) {
        self.stateService = stateService
        
        // Listen to state changes to automate recording
        stateService.$state
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func setupRecorderObservation() {
        // Observe recording state from AudioRecorder
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        // Setup timer to update recording duration
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                if let self = self, self.audioRecorder.isRecording {
                    self.recordingDuration = self.audioRecorder.recordingDuration
                }
            }
    }
    
    private func handleStateChange(_ state: InterviewState) {
        switch state {
        case .listeningForResponse:
            if !audioRecorder.isRecording {
                Task {
                    await startRecording()
                }
            }
            
        case .processingResponse:
            if audioRecorder.isRecording {
                _ = stopRecording()
            }
            
        case .paused, .finished, .error:
            if audioRecorder.isRecording {
                _ = stopRecording()
            }
            
        default:
            break
        }
    }
    
    // MARK: - Recording Control Methods
    
    func startRecording() async -> URL? {
        userExplicitlyStoppedRecording = false
        return await audioRecorder.startRecording()
    }
    
    func stopRecording() -> URL? {
        return audioRecorder.stopRecording()
    }
    
    func explicitStopRecording() -> URL? {
        userExplicitlyStoppedRecording = true
        return audioRecorder.stopRecording()
    }
    
    func pauseRecording() {
        audioRecorder.pauseRecording()
    }
    
    func resumeRecording() {
        audioRecorder.resumeRecording()
    }
    
    func resetTimer() {
        audioRecorder.resetTimer()
        recordingDuration = 0
    }
    
    func userStartedRecording() {
        userExplicitlyStoppedRecording = false
    }
    
    // MARK: - Speech Detection
    // Note: Speech detection is now handled by SilenceDetectionService
    // These methods are preserved for compatibility but no longer directly control AudioRecorder
    
    func enableSpeechDetection() {
        // Speech detection now managed externally by SilenceDetectionService
        // AudioRecorder delegates speech state updates
    }
    
    func disableSpeechDetection() {
        // Speech detection now managed externally by SilenceDetectionService
        // AudioRecorder delegates speech state updates
    }
    
    func setSpeechDetectionCallbacks(
        onSpeech: @escaping () -> Void,
        onSilence: @escaping () -> Void,
        onCountdownStarted: @escaping () -> Void = {},
        onCountdownStopped: @escaping () -> Void = {}
    ) {
        audioRecorder.setSpeechDetectionCallbacks(
            onSpeech: onSpeech,
            onSilence: onSilence,
            onCountdownStarted: onCountdownStarted,
            onCountdownStopped: onCountdownStopped
        )
    }
    
    // MARK: - Audio Session Management
    
    func resetAudioSession() async throws {
        await audioRecorder.resetAudioSession()
    }
    
    // MARK: - Permissions
    
    var permissionGranted: Bool {
        audioRecorder.permissionGranted
    }
    
    func requestPermission() {
        audioRecorder.requestPermission()
    }
    
    // MARK: - Additional Properties
    
    var getRecordingDuration: TimeInterval {
        audioRecorder.getRecordingDuration()
    }
    
    var isSpeechDetected: Bool {
        audioRecorder.isSpeechDetected
    }
    
    var showingSilenceCountdown: Bool {
        audioRecorder.showingSilenceCountdown
    }
    
    func stopSilenceCountdown() {
        // Silence countdown is now managed externally by SilenceDetectionService
        // AudioRecorder receives countdown state updates instead of controlling them
    }
}