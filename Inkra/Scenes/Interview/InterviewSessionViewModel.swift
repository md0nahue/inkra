//
//  InterviewSessionViewModel.swift
//  Inkra
//
//  Created by Magnus Fremont on 8/15/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - View State & Errors

enum ViewState: Equatable {
    case loading
    case loaded(project: Project, questionService: InterviewQuestionService, flowManager: InterviewFlowManager)
    case error(String)

    static func == (lhs: ViewState, rhs: ViewState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.error(let l), .error(let r)):
            return l == r
        case (.loaded(let lp, let lqs, let lfm), .loaded(let rp, let rqs, let rfm)):
            return lp == rp && lqs === rqs && lfm === rfm
        default:
            return false
        }
    }
}

struct TimeoutError: Error {}

// MARK: - ViewModel

@MainActor
class InterviewSessionViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    @Published var recordedSegments: [Int: AudioSegmentInfo] = [:]
    @Published var isCompleted: Bool = false
    @Published var currentInterviewState: InterviewState = .idle
    @Published var autoAdvanceOnSilence: Bool = true
    @Published var isPaused: Bool = false
    @Published var isAwaitingUserAction: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    private let project: Project
    var isReadingInterview: Bool { project.isSpeechInterview == false }
    var isSpeechInterview: Bool { project.isSpeechInterview == true }
    
    // Services that will be passed to the FlowManager
    private var nativeVoiceService = NativeVoiceService.shared
    var audioRecorder = AudioRecorder()
    private var cancellables = Set<AnyCancellable>()
    private var stateService: InterviewStateService?

    init(project: Project) {
        self.project = project
    }

    func loadInterviewData() async {
        guard case .loading = state else { return }

        do {
            try await withTimeout(seconds: 15) { [self] in
                let questionService = InterviewQuestionService(project: self.project)
                try await questionService.loadAvailableQuestions()
                
                let flowManager = InterviewFlowManager(
                    nativeVoiceService: self.nativeVoiceService,
                    audioRecorder: self.audioRecorder,
                    questionService: questionService,
                    isReadingInterview: self.isReadingInterview,
                    speechConfiguration: self.getSpeechConfiguration(),
                    getRecordedSegments: { [weak self] in self?.recordedSegments ?? [:] }
                )
                
                self.state = .loaded(project: self.project, questionService: questionService, flowManager: flowManager)
                
                if let firstQuestion = questionService.currentQuestion {
                    flowManager.startInterview(with: firstQuestion.id)
                }
            }
        } catch is TimeoutError {
            self.state = .error("The request timed out. Please check your connection and try again.")
        } catch {
            self.state = .error("An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    func retry() {
        state = .loading
        Task {
            await loadInterviewData()
        }
    }
    
    func getSpeechConfiguration() -> SpeechConfiguration {
        return SpeechConfiguration(isEnabled: true, voiceId: "Joanna", speechRate: 1)
    }

    func recordingCompleted(url: URL, duration: TimeInterval, for questionId: Int) {
        let segmentInfo = AudioSegmentInfo(questionId: questionId, localURL: url, duration: duration, audioSegmentId: nil, isUploaded: false)
        recordedSegments[questionId] = segmentInfo
        print("Recording completed for question \(questionId) and saved locally.")
    }
    
    func nextQuestionAndSave(questionService: InterviewQuestionService, flowManager: InterviewFlowManager) async {
        guard let currentQuestion = questionService.currentQuestion else { return }
        
        // Find next unanswered question
        let currentIndex = questionService.getCurrentQuestionIndex()
        if let nextIndex = questionService.findNextUnansweredQuestion(after: currentIndex, recordedSegments: recordedSegments) {
            questionService.setCurrentQuestionIndex(nextIndex)
            if let nextQuestion = questionService.currentQuestion {
                flowManager.advanceToNextQuestion(questionId: nextQuestion.id)
            }
        } else {
            // No more questions - complete interview
            await completeInterview()
        }
    }
    
    func skipQuestionAndDiscard(questionService: InterviewQuestionService, flowManager: InterviewFlowManager) async {
        guard let currentQuestion = questionService.currentQuestion else { return }
        
        do {
            try await questionService.skipQuestion(currentQuestion.id)
            
            // Find next unanswered question
            let currentIndex = questionService.getCurrentQuestionIndex()
            if let nextIndex = questionService.findNextUnansweredQuestion(after: currentIndex, recordedSegments: recordedSegments) {
                questionService.setCurrentQuestionIndex(nextIndex)
                if let nextQuestion = questionService.currentQuestion {
                    flowManager.advanceToNextQuestion(questionId: nextQuestion.id)
                }
            } else {
                // No more questions - complete interview
                await completeInterview()
            }
        } catch {
            errorMessage = "Failed to skip question: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func completeInterview() async {
        isCompleted = true
        // Additional cleanup if needed
    }
    
    func onViewDisappear() async {
        // Cleanup when view disappears
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
        }
        stateService?.cleanup()
    }
}

// MARK: - Helper Functions

func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        guard let result = try await group.next() else { throw CancellationError() }
        group.cancelAll()
        return result
    }
}
