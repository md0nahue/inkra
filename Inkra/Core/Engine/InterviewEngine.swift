import Foundation
import SwiftUI
import Combine

struct EngineTimeoutError: Error {}

@MainActor
class InterviewEngine: ObservableObject {
    
    // MARK: - State Management
    
    enum InterviewState: String {
        case idle = "idle"
        case initializing = "initializing"
        case loadingQuestion = "loading_question"
        case playingQuestion = "playing_question"
        case listening = "listening"
        case paused = "paused"
        case completed = "completed"
        case error = "error"
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var state: InterviewState = .idle
    @Published private(set) var currentQuestion: InterviewQuestion?
    @Published private(set) var currentQuestionIndex: Int = 0
    @Published private(set) var totalQuestions: Int = 0
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var errorMessage: String?
    @Published private(set) var isProcessingAnswer: Bool = false
    @Published private(set) var silenceCountdown: Int = 0
    @Published var autoAdvanceEnabled: Bool = true
    
    // MARK: - Services
    
    private let audioService: UnifiedAudioService
    private let questionRepository: QuestionRepository
    private let projectService: ProjectServiceProtocol
    private let uploadService: AudioServiceProtocol
    
    // MARK: - Internal Properties
    
    private var project: Project
    private var cancellables = Set<AnyCancellable>()
    private let silenceDetectionService = SilenceDetectionService()
    private var stateTransitionQueue = DispatchQueue(label: "interview.engine.state", qos: .userInitiated)
    private var silenceTimer: Timer? // Legacy compatibility for cleanup
    
    // MARK: - Helper Functions
    
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw EngineTimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Initialization
    
    init(project: Project, projectService: ProjectServiceProtocol = ProjectService(), uploadService: AudioServiceProtocol = AudioService()) {
        self.project = project
        self.projectService = projectService
        self.audioService = UnifiedAudioService()
        self.questionRepository = QuestionRepository(projectId: project.id, projectService: projectService)
        self.uploadService = uploadService
        
        setupBindings()
    }
    
    // MARK: - Public API
    
    func startInterview() async {
        do {
            // IMMEDIATE: Initialize audio service (fast, in parallel with data loading)
            let audioInitTask = Task { try await audioService.initialize() }
            
            // PROGRESSIVE: Try to get cached data first for instant startup
            if let cachedQuestions = await getCachedQuestions(), !cachedQuestions.isEmpty {
                try await audioInitTask.value // Ensure audio is ready
                await startWithCachedData(cachedQuestions)
                return
            }
            
            // If no cached data, try to load quickly without showing loading screen
            await transitionToState(.initializing)
            
            do {
                // Try to load initial questions with a very short timeout
                let questions = try await withTimeout(seconds: 1.5) {
                    try await self.questionRepository.loadInitialQuestions()
                }
                
                if !questions.isEmpty {
                    try await audioInitTask.value // Ensure audio is ready
                    await startWithQuickData(questions)
                } else {
                    // Fall back to minimal data if no questions available
                    try await audioInitTask.value
                    await startWithMinimalData()
                }
                
            } catch {
                // If timeout or error, fall back to minimal data approach
                try await audioInitTask.value
                await startWithMinimalData()
            }
            
            // BACKGROUND: Start full data loading and polling
            Task.detached(priority: .high) { [weak self] in
                await self?.enhanceWithFullQuestionSet()
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func startWithQuickData(_ questions: [InterviewQuestion]) async {
        self.totalQuestions = questions.count
        self.currentQuestionIndex = 0
        self.currentQuestion = questions.first
        
        // Start question repository background polling
        await questionRepository.startPolling()
        
        // Start playing first question immediately
        await playCurrentQuestion()
    }
    
    private func startWithCachedData(_ questions: [InterviewQuestion]) async {
        self.totalQuestions = questions.count
        self.currentQuestionIndex = 0
        self.currentQuestion = questions.first
        
        // Start question repository background polling
        await questionRepository.startPolling()
        
        // Start playing first question immediately
        await playCurrentQuestion()
    }
    
    private func startWithMinimalData() async {
        // Start question repository background polling immediately
        await questionRepository.startPolling()
        
        // Load questions in background but transition to ready state quickly
        Task(priority: .userInitiated) { [weak self] in
            await self?.loadFirstRealQuestion()
        }
        
        // Immediately transition to a non-blocking state to minimize loading time
        // Use a very short delay to give the impression of quick loading
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Show skeleton UI if we don't have real questions yet
        let skeletonQuestion = InterviewQuestion.skeleton()
        self.currentQuestion = skeletonQuestion
        self.totalQuestions = 1
        self.currentQuestionIndex = 0
        
        await transitionToState(.loadingQuestion)
    }
    
    
    private func loadFirstRealQuestion() async {
        do {
            let questions = try await questionRepository.loadInitialQuestions()
            
            if questions.isEmpty {
                throw InterviewEngineError.noQuestionsAvailable
            }
            
            await MainActor.run {
                self.totalQuestions = questions.count
                self.currentQuestionIndex = 0
                self.currentQuestion = questions.first
            }
            
            // Start playing first real question
            await playCurrentQuestion()
            
        } catch {
            await handleError(error)
        }
    }
    
    private func enhanceWithFullQuestionSet() async {
        // This runs in background to enhance the experience
        do {
            // Preload next few questions
            await preloadUpcomingQuestions()
            
            // Update total count if more questions become available
            let allQuestions = await questionRepository.getAllQuestions()
            await MainActor.run {
                if allQuestions.count > self.totalQuestions {
                    self.totalQuestions = allQuestions.count
                }
            }
            
        } catch {
            print("[InterviewEngine] Background enhancement failed: \(error)")
            // Don't interrupt the interview for background failures
        }
    }
    
    private func preloadUpcomingQuestions() async {
        // Preload audio for next 2-3 questions
        let upcomingRange = (currentQuestionIndex + 1)...(currentQuestionIndex + 3)
        let allQuestions = await questionRepository.getAllQuestions()
        
        for index in upcomingRange {
            guard index < allQuestions.count else { break }
            let question = allQuestions[index]
            
            // Preload audio in background
            if let audioUrl = question.audioUrl {
                Task(priority: .background) { [weak self] in
                    try? await self?.audioService.preloadAudio(from: audioUrl)
                }
            }
        }
    }
    
    private func getCachedQuestions() async -> [InterviewQuestion]? {
        // Try to get cached questions for instant startup
        return await questionRepository.getCachedQuestions(for: project.id)
    }
    
    func pauseInterview() async {
        guard state == .listening || state == .playingQuestion else { return }
        
        await transitionToState(.paused)
        await audioService.pauseAll()
        silenceDetectionService.disableSilenceDetection()
    }
    
    func resumeInterview() async {
        guard state == .paused else { return }
        
        if let currentQuestion = currentQuestion {
            await playQuestion(currentQuestion)
        } else {
            await transitionToState(.listening)
            await startListening()
        }
    }
    
    func skipQuestion() async {
        // Disable silence detection
        silenceDetectionService.disableSilenceDetection() 
        
        await audioService.stopRecording()
        await moveToNextQuestion()
    }
    
    func nextQuestion() async {
        await saveCurrentRecording()
        await moveToNextQuestion()
    }
    
    func stopAudioPlayback() async {
        await audioService.stopAllPlayback()
    }
    
    // MARK: - Debug/Manual Reset Methods
    
    func forceResetAudioLevel() {
        print("[InterviewEngine] 🔄 Manually forcing audio level reset")
        audioLevel = 0.0
    }
    
    func endInterview() async {
        await transitionToState(.completed)
        
        // Perform cleanup in background without blocking navigation
        Task.detached(priority: .background) { [weak self] in
            await self?.cleanup()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind audio level updates
        audioService.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                let oldLevel = self?.audioLevel ?? 0.0
                self?.audioLevel = level
                
                // Debug logging for audio level changes
                if level > 0.1 && oldLevel <= 0.1 {
                    print("[InterviewEngine] 📢 'You are talking!' indicator should show - audioLevel: \(level)")
                } else if level <= 0.1 && oldLevel > 0.1 {
                    print("[InterviewEngine] 🔇 'You are talking!' indicator should hide - audioLevel: \(level)")
                }
                
                if level != oldLevel && (level > 0.1 || oldLevel > 0.1) {
                    print("[InterviewEngine] 🎚️ Audio level update: \(oldLevel) → \(level), state: \(self?.state ?? .idle), isRecording: \(self?.isRecording ?? false)")
                }
            }
            .store(in: &cancellables)
        
        // Bind silence detection service
        silenceDetectionService.speechDetectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("[InterviewEngine] 🎤 Speech detected from SilenceDetectionService")
            }
            .store(in: &cancellables)
        
        silenceDetectionService.silenceDetectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("[InterviewEngine] 🔇 Silence detected from SilenceDetectionService")
                if self?.autoAdvanceEnabled == true {
                    Task { @MainActor [weak self] in
                        await self?.handleSilenceDetected()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Bind silence detection state for UI
        silenceDetectionService.$isCountdownActive
            .combineLatest(silenceDetectionService.$countdownSeconds)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive, seconds in
                if isActive {
                    self?.silenceCountdown = seconds
                } else {
                    self?.silenceCountdown = 0
                }
                print("[InterviewEngine] 🎯 Silence countdown: \(seconds) (active: \(isActive))")
            }
            .store(in: &cancellables)
        
        // Bind new questions from repository
        questionRepository.newQuestionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] questions in
                self?.handleNewQuestions(questions)
            }
            .store(in: &cancellables)
    }
    
    private func transitionToState(_ newState: InterviewState) async {
        await MainActor.run {
            self.state = newState
            print("[InterviewEngine] State transition: \(newState.rawValue)")
        }
    }
    
    private func playCurrentQuestion() async {
        guard let question = currentQuestion else {
            await moveToNextQuestion()
            return
        }
        
        await playQuestion(question)
    }
    
    private func playQuestion(_ question: InterviewQuestion) async {
        await transitionToState(.playingQuestion)
        
        do {
            // Stream audio directly from URL
            if let audioUrl = question.audioUrl {
                try await audioService.streamAudio(from: audioUrl)
            } else {
                // Fallback to TTS if no audio URL
                try await audioService.playText(question.text)
            }
            
            // Transition to listening after playback
            await transitionToState(.listening)
            await startListening()
            
        } catch {
            await handleError(error)
        }
    }
    
    private func startListening() async {
        do {
            try await audioService.startRecording()
            isRecording = true
            
            // Enable silence detection if auto-advance is enabled
            if autoAdvanceEnabled, let recorder = audioService.currentAudioRecorder {
                silenceDetectionService.enableSilenceDetection(with: recorder)
                print("[InterviewEngine] 🎯 Silence detection enabled for listening")
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func handleSilenceDetected() async {
        guard autoAdvanceEnabled, state == .listening else { return }
        
        // Silence countdown is handled by SilenceDetectionService
        await processAnswer()
    }
    
    private func processAnswer() async {
        print("[InterviewEngine] 🎤 Processing answer - stopping recording and resetting audio levels")
        isProcessingAnswer = true
        
        do {
            // Disable silence detection first
            silenceDetectionService.disableSilenceDetection()
            
            // Stop recording and get audio file
            let audioUrl = try await audioService.stopRecording()
            isRecording = false  // Ensure isRecording is reset after stopping
            
            // IMMEDIATE: Move to next question for smooth experience
            await moveToNextQuestion()
            
            // BACKGROUND: Upload audio without blocking UI
            if let audioUrl = audioUrl {
                Task.detached(priority: .background) { [weak self] in
                    do {
                        try await self?.uploadAudio(audioUrl)
                    } catch {
                        print("[InterviewEngine] Background upload failed: \(error)")
                        // Don't interrupt interview for upload failures
                    }
                }
            }
            
        } catch {
            await handleError(error)
        }
        
        isProcessingAnswer = false
    }
    
    private func saveCurrentRecording() async {
        guard isRecording else { return }
        
        print("[InterviewEngine] 💾 Saving current recording - resetting audio levels")
        // Disable silence detection
        silenceDetectionService.disableSilenceDetection()
        
        do {
            let audioUrl = try await audioService.stopRecording()
            isRecording = false  // Ensure isRecording is reset after stopping
            if let audioUrl = audioUrl {
                // BACKGROUND: Upload without blocking UI
                Task.detached(priority: .background) { [weak self] in
                    do {
                        try await self?.uploadAudio(audioUrl)
                    } catch {
                        print("[InterviewEngine] Background upload failed: \(error)")
                    }
                }
            }
        } catch {
            print("[InterviewEngine] Error saving recording: \(error)")
        }
        
        isRecording = false
    }
    
    private func uploadAudio(_ url: URL) async throws {
        guard let questionId = currentQuestion?.id else { return }
        
        do {
            // Read audio data from file
            let audioData = try Data(contentsOf: url)
            
            // Get file info
            let fileName = url.lastPathComponent
            let mimeType = "audio/m4a"
            
            // Calculate duration (simplified - in production would use AVAsset)
            let fileSize = Double(audioData.count)
            let estimatedDuration = fileSize / 44100.0 // Rough estimate
            
            // Request upload URL from server
            let uploadResponse = try await uploadService.requestUploadURL(
                projectId: project.id,
                fileName: fileName,
                mimeType: mimeType,
                duration: estimatedDuration,
                questionId: questionId
            )
            
            // Upload audio to S3
            try await uploadService.uploadAudio(data: audioData, to: uploadResponse.uploadUrl)
            
            // Notify server of successful upload
            _ = try await uploadService.notifyUploadComplete(
                projectId: project.id,
                audioSegmentId: uploadResponse.audioSegmentId,
                success: true,
                errorMessage: nil
            )
            
            // Mark question as answered
            questionRepository.markQuestionAnswered(questionId)
            
            print("[InterviewEngine] Successfully uploaded audio for question \(questionId)")
            
            // Clean up local file
            try? FileManager.default.removeItem(at: url)
            
        } catch {
            print("[InterviewEngine] Failed to upload audio: \(error)")
            // Don't throw - we don't want to stop the interview for upload failures
            // The audio is saved locally and can be uploaded later
        }
    }
    
    private func moveToNextQuestion() async {
        currentQuestionIndex += 1
        
        // Check if we have more questions
        let questions = await questionRepository.getAllQuestions()
        
        if currentQuestionIndex < questions.count {
            currentQuestion = questions[currentQuestionIndex]
            await playCurrentQuestion()
        } else {
            // Check if we're waiting for more questions
            let pendingQuestions = await questionRepository.hasPendingQuestions()
            
            if pendingQuestions {
                await transitionToState(.loadingQuestion)
                // Wait for new questions from polling
            } else {
                await endInterview()
            }
        }
    }
    
    private func handleNewQuestions(_ questions: [InterviewQuestion]) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Update total count
            self.totalQuestions = await self.questionRepository.getAllQuestions().count
            
            // If we're waiting for questions, play the next one
            if self.state == .loadingQuestion {
                if self.currentQuestionIndex < self.totalQuestions {
                    let allQuestions = await self.questionRepository.getAllQuestions()
                    self.currentQuestion = allQuestions[self.currentQuestionIndex]
                    await self.playCurrentQuestion()
                }
            }
        }
    }
    
    private func handleError(_ error: Error) async {
        // Determine if this is a recoverable error
        let recoveryStrategy = determineRecoveryStrategy(for: error)
        
        switch recoveryStrategy {
        case .retry:
            await attemptRecovery(error)
        case .gracefulDegradation:
            await degradeGracefully(error)
        case .showError:
            await transitionToState(.error)
            errorMessage = error.localizedDescription
        }
        
        // Log error for debugging
        ErrorLogger.shared.logError(error, context: "InterviewEngine", additionalData: ["state": state.rawValue])
    }
    
    private func determineRecoveryStrategy(for error: Error) -> ErrorRecoveryStrategy {
        switch error {
        case let networkError as URLError:
            // Network errors can often be retried
            return networkError.code == .timedOut ? .retry : .gracefulDegradation
            
        case InterviewEngineError.noQuestionsAvailable:
            // Try to use cached questions or show error
            return .gracefulDegradation
            
        case AudioServiceError.initializationFailed:
            // Audio issues can be retried once
            return .retry
            
        default:
            return .showError
        }
    }
    
    private func attemptRecovery(_ error: Error) async {
        print("[InterviewEngine] Attempting recovery from: \(error)")
        
        // Simple retry with backoff
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Retry the operation
        switch state {
        case .initializing:
            await startInterview()
        case .loadingQuestion:
            await loadFirstRealQuestion()
        default:
            await degradeGracefully(error)
        }
    }
    
    private func degradeGracefully(_ error: Error) async {
        print("[InterviewEngine] Graceful degradation for: \(error)")
        
        switch error {
        case InterviewEngineError.noQuestionsAvailable:
            // Show a basic question to keep interview flowing
            if let fallbackQuestion = createFallbackQuestion() {
                await MainActor.run {
                    self.currentQuestion = fallbackQuestion
                    self.totalQuestions = 1
                }
                await transitionToState(.playingQuestion)
            } else {
                await transitionToState(.error)
                errorMessage = "No questions available for this interview."
            }
            
        case let networkError as URLError:
            // Continue with cached data if available
            if let cachedQuestions = await getCachedQuestions() {
                await startWithCachedData(cachedQuestions)
            } else {
                await transitionToState(.error)
                errorMessage = "Network connection required to start interview."
            }
            
        default:
            await transitionToState(.error)
            errorMessage = error.localizedDescription
        }
    }
    
    private func createFallbackQuestion() -> InterviewQuestion? {
        return InterviewQuestion(
            questionId: -1,
            text: "Tell me about yourself and what you're hoping to explore in this interview.",
            order: 0,
            omitted: false,
            skipped: false,
            parentQuestionId: nil,
            isFollowUp: false,
            sectionId: 0,
            sectionTitle: "Introduction",
            chapterId: 0,
            chapterTitle: "Getting Started",
            pollyAudioUrl: nil
        )
    }
    
    private func cleanup() async {
        silenceDetectionService.disableSilenceDetection()
        await audioService.cleanup()
        await questionRepository.stopPolling()
        cancellables.removeAll()
        print("[InterviewEngine] Cleanup complete")
    }
    
    deinit {
        // Clean up synchronously without creating Tasks
        silenceTimer?.invalidate()
        silenceTimer = nil
        cancellables.removeAll()
        // Note: audioService and questionRepository will clean up in their own deinit
    }
}

// MARK: - Error Types

enum InterviewEngineError: LocalizedError {
    case noQuestionsAvailable
    case audioInitializationFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .noQuestionsAvailable:
            return "No interview questions available"
        case .audioInitializationFailed:
            return "Failed to initialize audio services"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

enum ErrorRecoveryStrategy {
    case retry
    case gracefulDegradation
    case showError
}

