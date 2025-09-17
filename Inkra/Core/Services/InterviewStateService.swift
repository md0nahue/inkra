import Foundation
import Combine

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class InterviewStateService: ObservableObject {
    @Published private(set) var state: InterviewState = .idle
    @Published var silenceCountdown: Int = 0
    @Published var showingSilenceCountdown = false
    
    private var flowManager: InterviewFlowManager
    private var cancellables = Set<AnyCancellable>()

    init(
        nativeVoiceService: NativeVoiceService,
        audioRecorder: AudioRecorder,
        questionService: InterviewQuestionService,
        isReadingInterview: Bool,
        speechConfiguration: SpeechConfiguration,
        getRecordedSegments: @escaping () -> [Int: AudioSegmentInfo]
    ) {
        self.flowManager = InterviewFlowManager(
            nativeVoiceService: nativeVoiceService,
            audioRecorder: audioRecorder,
            questionService: questionService,
            isReadingInterview: isReadingInterview,
            speechConfiguration: speechConfiguration,
            getRecordedSegments: getRecordedSegments
        )
        
        flowManager.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
        
        flowManager.$silenceCountdown
            .receive(on: DispatchQueue.main)
            .assign(to: &$silenceCountdown)
        
        flowManager.$showingSilenceCountdown
            .receive(on: DispatchQueue.main)
            .assign(to: &$showingSilenceCountdown)
    }
    
    // MARK: - State Management Methods
    
    func startInterview(with questionId: Int) {
        flowManager.transition(to: .playingQuestionAudio(questionId: questionId))
    }
    
    func pauseInterview() {
        flowManager.transition(to: .paused)
    }
    
    func resumeInterview() {
        flowManager.resumeInterview()
    }
    
    func finishInterview() {
        flowManager.transition(to: .finished)
    }
    
    func advanceToNextQuestion(questionId: Int) {
        flowManager.transition(to: .playingQuestionAudio(questionId: questionId))
    }
    
    func handleError(_ message: String) {
        flowManager.transition(to: .error(message))
    }
    
    func transitionTo(_ newState: InterviewState) {
        flowManager.transition(to: newState)
    }
    
    var currentState: InterviewState {
        state
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        cancellables.removeAll()
        flowManager.cleanup()
        state = .idle
        silenceCountdown = 0
        showingSilenceCountdown = false
    }
}
