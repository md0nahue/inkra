import Foundation
import Combine
import AVFoundation

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class InterviewManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentState: InterviewFlowState = .idle
    @Published private(set) var currentQuestion: Question?
    @Published private(set) var isRecording = false
    @Published private(set) var isPlayingQuestion = false
    @Published private(set) var questionNumber: String = "1"
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoadingNextQuestion = false

    // MARK: - Services
    private let nativeSpeechService = NativeSpeechService.shared
    private let nativeVoiceService = NativeVoiceService.shared
    private let audioRecorder = AudioRecorder()
    private var questionService: InterviewQuestionService?
    private let questionsManager = DailyQuestionsManager()
    private let networkService = NetworkService.shared
    private let featureFlags = FeatureFlagManager.shared

    // MARK: - Configuration
    private var project: Project?
    private var voiceId: String = "Matthew"
    private var speechRate: Double = 1.0
    private var useDailyQuestions: Bool = false
    private var dailyQuestions: [DailyQuestion] = []
    private var currentDailyQuestionIndex = 0

    // MARK: - State Management
    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    private var silenceTimer: Timer?
    private var recordedSegments: [Int: AudioSegmentInfo] = [:]
    private var offlineQueue: [OfflineOperation] = []
    private var retryCount: [String: Int] = [:]
    private let maxRetries = 3
    private let retryBackoffMultiplier = 2.0

    enum InterviewFlowState {
        case idle
        case starting
        case playingQuestion
        case waitingForSpeech
        case recording
        case processingAnswer
        case generatingNextQuestion
        case paused
        case completed
        case error(String)
    }

    // MARK: - Initialization
    init() {
        setupBindings()
        loadUserPreferences()
    }

    private func setupBindings() {
        // Monitor native speech recognition changes
        nativeSpeechService.$isListening
            .sink { [weak self] isListening in
                self?.isRecording = isListening
            }
            .store(in: &cancellables)

        // Monitor speech recognition errors
        nativeSpeechService.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.handleError("Speech recognition error: \(error)")
            }
            .store(in: &cancellables)

        // Monitor transcription updates
        nativeSpeechService.onFinalTranscription = { [weak self] transcription in
            Task { @MainActor in
                await self?.handleFinalTranscription(transcription)
            }
        }
    }

    private func loadUserPreferences() {
        voiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? "Matthew"
        speechRate = UserDefaults.standard.double(forKey: "default_speech_rate")
        if speechRate <= 0 {
            speechRate = 1.0
        }
    }

    // MARK: - Interview Configuration
    func startMagicalInterview(with project: Project? = nil, useDailyQuestions: Bool = false) async {
        print("🚀 Starting magical interview - useDailyQuestions: \(useDailyQuestions)")

        self.project = project
        self.useDailyQuestions = useDailyQuestions
        self.recordedSegments = [:]
        self.currentDailyQuestionIndex = 0

        currentState = .starting

        do {
            if useDailyQuestions {
                await setupDailyQuestionsFlow()
            } else if let project = project {
                await setupProjectFlow(project)
            } else {
                throw InterviewError.noQuestionsAvailable
            }

            await beginInterviewFlow()
        } catch {
            await handleNetworkError(error, operation: .startInterview)
        }
    }

    private func setupDailyQuestionsFlow() async {
        dailyQuestions = questionsManager.getEnabledQuestions()

        if dailyQuestions.isEmpty {
            handleError("No daily questions available")
            return
        }

        // Shuffle for variety
        dailyQuestions.shuffle()

        // Create Question objects from DailyQuestion
        let questions = dailyQuestions.enumerated().map { index, dailyQ in
            Question(
                id: index + 1000, // Use high IDs to avoid conflicts
                text: dailyQ.text,
                order: index,
                isFollowUp: false,
                omitted: false,
                parentQuestionId: nil
            )
        }

        // Set up a mock question service for daily questions
        setupMockQuestionService(with: questions)

        currentQuestion = questions.first
        questionNumber = "1"
        progress = 0.0

        print("✅ Set up daily questions flow with \(questions.count) questions")
    }

    private func setupProjectFlow(_ project: Project) async {
        do {
            questionService = InterviewQuestionService(project: project)
            try await questionService?.loadAvailableQuestions()

            if let firstQuestion = questionService?.currentQuestion {
                currentQuestion = firstQuestion
                questionNumber = questionService?.getQuestionDisplayNumber(for: firstQuestion) ?? "1"
                progress = 0.0
            } else {
                throw InterviewError.noQuestionsAvailable
            }

            print("✅ Set up project flow with questions")
        } catch {
            throw error
        }
    }

    private func setupMockQuestionService(with questions: [Question]) {
        // Create a simplified in-memory question service for daily questions
        // This allows reuse of existing question flow logic
        questionService = nil // We'll handle daily questions directly
        currentQuestion = questions.first
    }

    // MARK: - Interview Flow Control
    private func beginInterviewFlow() async {
        guard let question = currentQuestion else {
            handleError("No question available to start interview")
            return
        }

        currentState = .playingQuestion
        await playQuestionAudio(question)
    }

    private func playQuestionAudio(_ question: Question) async {
        print("🎵 Playing question audio: \(question.text)")

        isPlayingQuestion = true

        do {
            if useDailyQuestions {
                // Generate and play audio for daily questions
                await generateAndPlayQuestionAudio(question.text)
            } else {
                // Use existing question audio from server
                if let questionService = questionService,
                   let audioUrl = questionService.pollyAudioUrls[question.id] {
                    nativeVoiceService.speak(text: question.text, utteranceId: question.id)
                } else {
                    // Fallback: generate audio for the question
                    await generateAndPlayQuestionAudio(question.text)
                }
            }

            // Wait for audio to finish playing
            await waitForAudioCompletion()

            isPlayingQuestion = false
            currentState = .waitingForSpeech

            // Start recording after a brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task { await self.startRecordingResponse() }
            }

        } catch {
            isPlayingQuestion = false
            handleError("Failed to play question audio: \(error.localizedDescription)")
        }
    }

    private func generateAndPlayQuestionAudio(_ questionText: String) async {
        nativeVoiceService.speak(text: questionText)
    }

    private func waitForAudioCompletion() async {
        // Poll for audio completion - in a real implementation you'd use proper audio completion callbacks
        while nativeVoiceService.isPlaying {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }

    private func startRecordingResponse() async {
        guard currentState == .waitingForSpeech else { return }

        print("🎤 Starting to record user response")
        currentState = .recording

        do {
            // Start native speech recognition
            try nativeSpeechService.startListening()

            // Start recording timer for auto-stop
            startRecordingTimer()

            // Start silence detection timer
            startSilenceTimer()

        } catch {
            handleError("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func startRecordingTimer() {
        // Auto-stop recording after 2 minutes
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: false) { [weak self] _ in
            Task {
                await self?.finishRecording()
            }
        }
    }

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkForSilence()
        }
    }

    private func checkForSilence() {
        // If we haven't received new transcription in a while, consider finishing
        // This is a simplified implementation - the NativeSpeechService has its own silence detection
        let transcriptionText = nativeSpeechService.transcriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !transcriptionText.isEmpty && transcriptionText.count > 10 {
            // User has spoken enough, prepare to finish recording
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                Task {
                    if self.currentState == .recording {
                        await self.finishRecording()
                    }
                }
            }
        }
    }

    func finishRecording() async {
        guard currentState == .recording else { return }

        print("⏹️ Finishing recording")
        currentState = .processingAnswer

        // Stop all recording
        recordingTimer?.invalidate()
        silenceTimer?.invalidate()
        nativeSpeechService.stopListening()

        let transcriptionText = nativeSpeechService.transcriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        if transcriptionText.isEmpty {
            handleError("No speech detected. Please try again.")
            return
        }

        // Store the recording
        if let currentQuestion = currentQuestion {
            recordedSegments[currentQuestion.id] = AudioSegmentInfo(
                questionId: currentQuestion.id,
                localURL: nil,
                duration: 30.0, // Placeholder
                audioSegmentId: nil,
                isUploaded: false,
                textResponse: transcriptionText
            )
        }

        print("✅ Recorded answer: \(transcriptionText)")

        // Move to next question
        await proceedToNextQuestion()
    }

    private func handleFinalTranscription(_ transcription: String) async {
        // This method is called when the native speech service provides final transcription
        // It automatically handles the completion of speech recognition
        if currentState == .recording {
            await finishRecording()
        }
    }

    private func proceedToNextQuestion() async {
        currentState = .generatingNextQuestion
        isLoadingNextQuestion = true

        do {
            if useDailyQuestions {
                await moveToNextDailyQuestion()
            } else {
                await moveToNextProjectQuestion()
            }
        } catch {
            handleError("Failed to generate next question: \(error.localizedDescription)")
        }

        isLoadingNextQuestion = false
    }

    private func moveToNextDailyQuestion() async {
        currentDailyQuestionIndex += 1

        if currentDailyQuestionIndex >= dailyQuestions.count {
            // Interview complete
            currentState = .completed
            print("🎉 Daily questions interview completed!")
            return
        }

        // Create next question
        let nextDailyQuestion = dailyQuestions[currentDailyQuestionIndex]
        let nextQuestion = Question(
            id: currentDailyQuestionIndex + 1000,
            text: nextDailyQuestion.text,
            order: currentDailyQuestionIndex,
            isFollowUp: false,
            omitted: false,
            parentQuestionId: nil
        )

        currentQuestion = nextQuestion
        questionNumber = "\(currentDailyQuestionIndex + 1)"
        progress = Double(currentDailyQuestionIndex + 1) / Double(dailyQuestions.count)

        // Continue with next question
        currentState = .playingQuestion
        await playQuestionAudio(nextQuestion)
    }

    private func moveToNextProjectQuestion() async {
        guard let questionService = questionService else {
            currentState = .completed
            return
        }

        // Try to check for follow-up questions first
        if let currentQuestion = currentQuestion {
            do {
                try await questionService.checkForFollowUpQuestions(for: currentQuestion.id)
            } catch {
                print("⚠️ Failed to check for follow-up questions: \(error)")
            }
        }

        // Find next unanswered question
        let currentIndex = questionService.getCurrentQuestionIndex()
        if let nextIndex = questionService.findNextUnansweredQuestion(after: currentIndex, recordedSegments: recordedSegments) {
            questionService.setCurrentQuestionIndex(nextIndex)

            if let nextQuestion = questionService.currentQuestion {
                currentQuestion = nextQuestion
                questionNumber = questionService.getQuestionDisplayNumber(for: nextQuestion)
                progress = Double(nextIndex + 1) / Double(questionService.totalQuestions)

                // Continue with next question
                currentState = .playingQuestion
                await playQuestionAudio(nextQuestion)
            } else {
                currentState = .completed
            }
        } else {
            // No more questions - interview complete
            currentState = .completed
            print("🎉 Project interview completed!")
        }
    }

    // MARK: - Manual Controls
    func pauseInterview() {
        guard currentState != .idle && currentState != .completed else { return }

        recordingTimer?.invalidate()
        silenceTimer?.invalidate()
        nativeSpeechService.stopListening()
        nativeVoiceService.pauseSpeaking()

        currentState = .paused
        print("⏸️ Interview paused")
    }

    func resumeInterview() async {
        guard currentState == .paused else { return }

        switch currentState {
        case .recording:
            await startRecordingResponse()
        case .playingQuestion:
            if let question = currentQuestion {
                await playQuestionAudio(question)
            }
        default:
            currentState = .waitingForSpeech
        }

        print("▶️ Interview resumed")
    }

    func skipCurrentQuestion() async {
        guard let currentQuestion = currentQuestion else { return }

        // Mark as skipped
        if let questionService = questionService {
            try? await questionService.skipQuestion(currentQuestion.id)
        }

        print("⏭️ Skipped question: \(currentQuestion.text)")
        await proceedToNextQuestion()
    }

    func stopInterview() {
        recordingTimer?.invalidate()
        silenceTimer?.invalidate()
        nativeSpeechService.stopListening()
        nativeVoiceService.stopSpeaking()

        currentState = .idle
        currentQuestion = nil
        progress = 0.0
        errorMessage = nil

        print("🛑 Interview stopped")
    }

    // MARK: - Error Handling
    private func handleError(_ message: String, recoverable: Bool = true) {
        recordingTimer?.invalidate()
        silenceTimer?.invalidate()
        nativeSpeechService.stopListening()

        errorMessage = message

        if recoverable {
            // Attempt recovery
            Task {
                await attemptErrorRecovery(message)
            }
        } else {
            currentState = .error(message)
        }

        print("❌ Interview error: \(message)")
    }

    // MARK: - Public Interface
    var isActive: Bool {
        switch currentState {
        case .idle, .completed, .error:
            return false
        default:
            return true
        }
    }

    var canRecord: Bool {
        currentState == .waitingForSpeech
    }

    var canPause: Bool {
        switch currentState {
        case .playingQuestion, .recording, .waitingForSpeech:
            return true
        default:
            return false
        }
    }

    var canSkip: Bool {
        switch currentState {
        case .playingQuestion, .waitingForSpeech, .recording:
            return true
        default:
            return false
        }
    }

    // MARK: - Enhanced Error Handling & Recovery

    private func attemptErrorRecovery(_ errorMessage: String) async {
        print("🔄 Attempting error recovery for: \(errorMessage)")

        // Check if we can continue with cached data
        if await tryOfflineMode() {
            return
        }

        // Try to restart the current operation
        if await retryCurrentOperation() {
            return
        }

        // Fall back to error state
        currentState = .error(errorMessage)
    }

    private func handleNetworkError(_ error: Error, operation: OfflineOperation) async {
        guard featureFlags.isEnabled(.offlineMode) else {
            handleError("Network error: \(error.localizedDescription)", recoverable: false)
            return
        }

        print("📱 Network error, queuing operation for offline: \(operation)")

        // Queue operation for retry when network returns
        offlineQueue.append(operation)

        // Try to continue with cached data
        if await tryOfflineMode() {
            handleError("Working offline - changes will sync when connected", recoverable: true)
        } else {
            handleError("Network connection required", recoverable: false)
        }
    }

    private func retryCurrentOperation() async -> Bool {
        let operationId = "current_operation"
        let currentRetryCount = retryCount[operationId] ?? 0

        guard currentRetryCount < maxRetries else {
            print("❌ Max retries exceeded for current operation")
            return false
        }

        // Exponential backoff
        let delay = pow(retryBackoffMultiplier, Double(currentRetryCount))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        retryCount[operationId] = currentRetryCount + 1

        // Retry based on current state
        switch currentState {
        case .starting:
            // Retry starting the interview
            if let project = project {
                do {
                    if useDailyQuestions {
                        await setupDailyQuestionsFlow()
                    } else {
                        await setupProjectFlow(project)
                    }
                    await beginInterviewFlow()
                    return true
                } catch {
                    return false
                }
            }
        case .generatingNextQuestion:
            // Retry question generation
            await proceedToNextQuestion()
            return true
        default:
            break
        }

        return false
    }

    private func tryOfflineMode() async -> Bool {
        guard featureFlags.isEnabled(.offlineMode) else {
            return false
        }

        // Check if we have cached questions to continue
        if useDailyQuestions && !dailyQuestions.isEmpty {
            print("📱 Continuing with cached daily questions")
            return true
        }

        // Check if we have cached project questions
        if let questionService = questionService,
           questionService.hasAvailableQuestions {
            print("📱 Continuing with cached project questions")
            return true
        }

        return false
    }

    func processOfflineQueue() async {
        guard networkService.isConnected else { return }

        print("📶 Network restored, processing offline queue (\(offlineQueue.count) operations)")

        for operation in offlineQueue {
            do {
                try await processOfflineOperation(operation)
            } catch {
                print("⚠️ Failed to process offline operation: \(error)")
            }
        }

        offlineQueue.removeAll()
        retryCount.removeAll()
    }

    private func processOfflineOperation(_ operation: OfflineOperation) async throws {
        switch operation {
        case .startInterview:
            // Retry starting interview
            if let project = project {
                if useDailyQuestions {
                    await setupDailyQuestionsFlow()
                } else {
                    await setupProjectFlow(project)
                }
            }
        case .generateQuestion:
            // Retry question generation
            await proceedToNextQuestion()
        case .saveResponse(let questionId, let transcription):
            // Sync recorded response
            try await syncRecordedResponse(questionId: questionId, transcription: transcription)
        case .uploadAudio(let audioURL):
            // Upload queued audio
            try await uploadQueuedAudio(audioURL)
        }
    }

    private func syncRecordedResponse(questionId: Int, transcription: String) async throws {
        // Implementation would sync with backend
        print("📤 Syncing response for question \(questionId)")
    }

    private func uploadQueuedAudio(_ audioURL: URL) async throws {
        // Implementation would upload audio file
        print("📤 Uploading queued audio: \(audioURL.lastPathComponent)")
    }

    // MARK: - Circuit Breaker Pattern

    private func executeWithCircuitBreaker<T>(
        operation: String,
        action: () async throws -> T
    ) async throws -> T {
        let circuitBreaker = CircuitBreakerManager.shared.getCircuitBreaker(for: operation)

        return try await circuitBreaker.execute {
            return try await action()
        }
    }

    // MARK: - Improved Question Generation with Fallback

    private func generateQuestionsWithFallback() async throws -> [Question] {
        // Try AWS Lambda first if enabled
        if featureFlags.isEnabled(.awsBackend) {
            do {
                return try await executeWithCircuitBreaker(operation: "lambda_questions") {
                    return try await generateQuestionsFromLambda()
                }
            } catch {
                print("⚠️ Lambda generation failed, falling back to cached questions")
                return getCachedFallbackQuestions()
            }
        }

        // Use cached questions if AWS is disabled
        return getCachedFallbackQuestions()
    }

    private func generateQuestionsFromLambda() async throws -> [Question] {
        // Implementation would call Lambda function
        throw NetworkError.serviceUnavailable
    }

    private func getCachedFallbackQuestions() -> [Question] {
        // Return pre-defined fallback questions
        return [
            Question(
                id: 9001,
                text: "Tell me about yourself and your background.",
                order: 0,
                isFollowUp: false,
                omitted: false,
                parentQuestionId: nil
            ),
            Question(
                id: 9002,
                text: "What are your greatest strengths?",
                order: 1,
                isFollowUp: false,
                omitted: false,
                parentQuestionId: nil
            ),
            Question(
                id: 9003,
                text: "Describe a challenging situation you faced and how you handled it.",
                order: 2,
                isFollowUp: false,
                omitted: false,
                parentQuestionId: nil
            )
        ]
    }
}

// MARK: - Enhanced Supporting Types

enum OfflineOperation {
    case startInterview
    case generateQuestion
    case saveResponse(questionId: Int, transcription: String)
    case uploadAudio(url: URL)
}

enum NetworkError: LocalizedError {
    case connectionLost
    case serviceUnavailable
    case timeout
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .connectionLost:
            return "Connection lost"
        case .serviceUnavailable:
            return "Service temporarily unavailable"
        case .timeout:
            return "Request timed out"
        case .rateLimited:
            return "Rate limit exceeded"
        }
    }
}

// MARK: - Circuit Breaker Implementation

class CircuitBreakerManager {
    static let shared = CircuitBreakerManager()
    private var circuitBreakers: [String: CircuitBreaker] = [:]

    func getCircuitBreaker(for operation: String) -> CircuitBreaker {
        if let existingBreaker = circuitBreakers[operation] {
            return existingBreaker
        }

        let newBreaker = CircuitBreaker(
            name: operation,
            failureThreshold: 3,
            resetTimeout: 60.0
        )
        circuitBreakers[operation] = newBreaker
        return newBreaker
    }
}

class CircuitBreaker {
    enum State {
        case closed, open, halfOpen
    }

    private let name: String
    private var state: State = .closed
    private var failureCount = 0
    private let failureThreshold: Int
    private let resetTimeout: TimeInterval
    private var lastFailureTime: Date?

    init(name: String, failureThreshold: Int, resetTimeout: TimeInterval) {
        self.name = name
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }

    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        switch state {
        case .open:
            if shouldAttemptReset() {
                state = .halfOpen
                print("🔧 Circuit breaker \(name) transitioning to half-open")
            } else {
                throw CircuitBreakerError.circuitOpen(name)
            }
        case .halfOpen:
            // Allow one test request through
            break
        case .closed:
            // Normal operation
            break
        }

        do {
            let result = try await operation()
            onSuccess()
            return result
        } catch {
            onFailure()
            throw error
        }
    }

    private func onSuccess() {
        failureCount = 0
        if state == .halfOpen {
            state = .closed
            print("✅ Circuit breaker \(name) reset to closed")
        }
    }

    private func onFailure() {
        failureCount += 1
        lastFailureTime = Date()

        if failureCount >= failureThreshold {
            state = .open
            print("🚨 Circuit breaker \(name) opened due to failures")
        }
    }

    private func shouldAttemptReset() -> Bool {
        guard let lastFailure = lastFailureTime else { return false }
        return Date().timeIntervalSince(lastFailure) >= resetTimeout
    }
}

enum CircuitBreakerError: LocalizedError {
    case circuitOpen(String)

    var errorDescription: String? {
        switch self {
        case .circuitOpen(let name):
            return "Circuit breaker for \(name) is open"
        }
    }
}

// MARK: - Mock Network Service

class NetworkService {
    static let shared = NetworkService()

    var isConnected: Bool {
        // In real implementation, check actual network connectivity
        return true
    }
}

// MARK: - Supporting Types
enum InterviewError: LocalizedError {
    case noQuestionsAvailable
    case audioGenerationFailed
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .noQuestionsAvailable:
            return "No questions available for interview"
        case .audioGenerationFailed:
            return "Failed to generate question audio"
        case .recordingFailed:
            return "Failed to record response"
        }
    }
}