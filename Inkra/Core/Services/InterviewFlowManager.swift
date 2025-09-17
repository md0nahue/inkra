import Foundation
import Combine

enum InterviewState: Equatable {
    case idle
    case playingQuestionAudio(questionId: Int)
    case listeningForResponse
    case userIsSpeaking
    case processingResponse(lastQuestionId: Int)
    case userActionRequired(lastQuestionId: Int)
    case paused
    case finished
    case error(String)
}

struct SpeechConfiguration {
    let isEnabled: Bool
    let voiceId: String
    let speechRate: Int
}

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class InterviewFlowManager: ObservableObject {
    @Published private(set) var state: InterviewState = .idle
    @Published var silenceCountdown: Int = 0
    @Published var showingSilenceCountdown = false
    
    private let nativeVoiceService: NativeVoiceService
    private let audioRecorder: AudioRecorder
    private let questionService: InterviewQuestionService
    private let isReadingInterview: Bool
    private let speechConfiguration: SpeechConfiguration
    private var getRecordedSegments: () -> [Int: AudioSegmentInfo]

    private var silenceTimer: Timer?
    private var countdownTimer: Timer?
    
    init(
        nativeVoiceService: NativeVoiceService,
        audioRecorder: AudioRecorder,
        questionService: InterviewQuestionService,
        isReadingInterview: Bool,
        speechConfiguration: SpeechConfiguration,
        getRecordedSegments: @escaping () -> [Int: AudioSegmentInfo]
    ) {
        self.nativeVoiceService = nativeVoiceService
        self.audioRecorder = audioRecorder
        self.questionService = questionService
        self.isReadingInterview = isReadingInterview
        self.speechConfiguration = speechConfiguration
        self.getRecordedSegments = getRecordedSegments
        setupCallbacks()
    }
    
    func transition(to newState: InterviewState) {
        self.state = newState
        executeAction(for: newState)
    }
    
    private func executeAction(for state: InterviewState) {
        switch state {
        case .idle:
            nativeVoiceService.stopSpeaking()
            audioRecorder.stopPlayback()
            cancelSilenceTimer()
            
        case .playingQuestionAudio(let questionId):
            if audioRecorder.isRecording {
                _ = audioRecorder.stopRecording()
            }
            // Audio recording prevention logic simplified
            
            if isReadingInterview {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    // Speech detection logic simplified
                    self.transition(to: .listeningForResponse)
                }
                return
            }
            
            guard let audioUrl = questionService.pollyAudioUrls[questionId] else {
                Task { @MainActor in
                    // Speech detection logic simplified
                    self.transition(to: .listeningForResponse)
                }
                return
            }
            
            if let question = questionService.questions.first(where: { $0.id == questionId }) {
                nativeVoiceService.speak(text: question.text, utteranceId: "\(questionId)")
            }
            
        case .listeningForResponse:
            // Audio recording and speech detection simplified
            startSilenceTimer()
            
        case .userIsSpeaking:
            cancelSilenceTimer()
            
        case .processingResponse:
            // Speech detection disabled via simplified architecture
            cancelSilenceTimer()
            
        case .userActionRequired:
            // Speech detection disabled via simplified architecture
            cancelSilenceTimer()
            
        case .paused:
            nativeVoiceService.stopSpeaking()
            // Speech detection disabled via simplified architecture
            cancelSilenceTimer()
            
        case .finished:
            nativeVoiceService.stopSpeaking()
            // Speech detection disabled via simplified architecture
            cancelSilenceTimer()
            if audioRecorder.isRecording {
                _ = audioRecorder.stopRecording()
            }
            
        case .error(let message):
            print("❌ InterviewFlowManager error: \(message)")
            nativeVoiceService.stopSpeaking()
            // Speech detection disabled via simplified architecture
            cancelSilenceTimer()
        }
    }
    
    private func setupCallbacks() {
        nativeVoiceService.onSpeechFinished = { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if case .playingQuestionAudio = self.state {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self.transition(to: .listeningForResponse)
                }
            }
        }
        
        audioRecorder.setSpeechDetectionCallbacks(
            onSpeech: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    if case .listeningForResponse = self.state {
                        self.transition(to: .userIsSpeaking)
                    } else if case .userIsSpeaking = self.state {
                        self.cancelSilenceTimer()
                    }
                }
            },
            onSilence: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    if case .userIsSpeaking = self.state {
                        self.startSilenceTimer()
                    }
                }
            }
        )
    }
    
    func startInterview(with questionId: Int) {
        transition(to: .playingQuestionAudio(questionId: questionId))
    }
    
    func pauseInterview() {
        transition(to: .paused)
    }
    
    func resumeInterview() {
        let recordedSegments = getRecordedSegments()
        let nextUnansweredIndex = questionService.dynamicQuestionQueue.firstIndex { recordedSegments[$0.id] == nil }
        
        if let nextIndex = nextUnansweredIndex {
            let nextQuestion = questionService.dynamicQuestionQueue[nextIndex]
            questionService.setCurrentQuestionIndex(nextIndex)
            transition(to: .playingQuestionAudio(questionId: nextQuestion.id))
        } else {
            transition(to: .finished)
        }
    }
    
    func finishInterview() {
        transition(to: .finished)
    }
    
    func handleError(_ message: String) {
        transition(to: .error(message))
    }
    
    func advanceToNextQuestion(questionId: Int) {
        transition(to: .playingQuestionAudio(questionId: questionId))
    }
    
    private func startSilenceTimer() {
        cancelSilenceTimer()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.startCountdown()
            }
        }
    }
    
    private func startCountdown() {
        silenceCountdown = 3
        showingSilenceCountdown = true
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { return }
                if self.silenceCountdown > 1 {
                    self.silenceCountdown -= 1
                } else {
                    timer.invalidate()
                    self.showingSilenceCountdown = false
                    if case .userIsSpeaking = self.state, let currentQuestion = self.questionService.currentQuestion {
                        self.transition(to: .processingResponse(lastQuestionId: currentQuestion.id))
                    }
                }
            }
        }
    }
    
    private func cancelSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        showingSilenceCountdown = false
        silenceCountdown = 0
    }
    
    func cleanup() {
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
        }
        cancelSilenceTimer()
        state = .idle
    }
}
