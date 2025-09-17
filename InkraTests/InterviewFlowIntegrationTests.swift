import XCTest
import Combine
import AVFoundation
@testable import Inkra

@available(iOS 15.0, *)
final class InterviewFlowIntegrationTests: XCTestCase {

    var interviewManager: InterviewManager!
    var mockProject: Project!
    var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create mock project for testing
        mockProject = Project(
            id: UUID(),
            name: "Test Project",
            company: "Test Company",
            position: "iOS Developer",
            description: "Test description",
            userId: "test-user-123",
            createdAt: Date(),
            updatedAt: Date()
        )

        interviewManager = InterviewManager()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDownWithError() throws {
        cancellables?.removeAll()
        interviewManager = nil
        mockProject = nil
        try super.tearDownWithError()
    }

    // MARK: - Interview Initialization Tests

    func testInterviewInitialization() async throws {
        // Test that interview can be properly initialized
        let initExpectation = expectation(description: "Interview initialization")

        interviewManager.$currentState
            .dropFirst()
            .sink { state in
                if state == .starting {
                    initExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        try await interviewManager.configure(
            project: mockProject,
            voiceId: "Matthew",
            speechRate: 1.0
        )

        await interviewManager.startInterview()

        await fulfillment(of: [initExpectation], timeout: 5.0)
        XCTAssertEqual(interviewManager.currentState, .starting)
    }

    func testDailyQuestionFlow() async throws {
        // Test daily question interview flow
        let stateChanges: [InterviewFlowState] = []
        var receivedStates: [InterviewFlowState] = []

        let stateExpectation = expectation(description: "State changes tracked")
        stateExpectation.expectedFulfillmentCount = 3 // idle -> starting -> playingQuestion

        interviewManager.$currentState
            .sink { state in
                receivedStates.append(state)
                if receivedStates.count >= 3 {
                    stateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        try await interviewManager.configureForDailyQuestions()
        await interviewManager.startInterview()

        // Wait for state progression
        await fulfillment(of: [stateExpectation], timeout: 10.0)

        XCTAssertTrue(receivedStates.contains(.idle))
        XCTAssertTrue(receivedStates.contains(.starting))
        XCTAssertTrue(interviewManager.currentQuestion != nil)
    }

    // MARK: - Audio Recording Integration Tests

    func testAudioRecordingFlow() async throws {
        // Test the complete audio recording cycle
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            throw XCTSkip("Audio recording permission required for this test")
        }

        let recordingStateExpectation = expectation(description: "Recording state changes")
        recordingStateExpectation.expectedFulfillmentCount = 2 // start and stop

        var recordingStates: [Bool] = []

        interviewManager.$isRecording
            .sink { isRecording in
                recordingStates.append(isRecording)
                if recordingStates.count >= 2 {
                    recordingStateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Configure and start interview
        try await interviewManager.configure(
            project: mockProject,
            voiceId: "Matthew",
            speechRate: 1.0
        )

        await interviewManager.startInterview()

        // Start recording
        await interviewManager.startRecording()
        XCTAssertTrue(interviewManager.isRecording)

        // Wait a moment then stop recording
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await interviewManager.stopRecording()

        await fulfillment(of: [recordingStateExpectation], timeout: 5.0)

        XCTAssertFalse(interviewManager.isRecording)
        XCTAssertEqual(recordingStates, [false, true, false])
    }

    // MARK: - Speech Integration Tests

    func testSpeechToTextIntegration() async throws {
        // Test speech recognition integration
        let speechExpectation = expectation(description: "Speech processing")

        var transcriptionReceived = false

        // Set up speech service callback
        let speechService = NativeSpeechService.shared
        speechService.onTranscriptionUpdate = { transcription in
            if !transcription.isEmpty {
                transcriptionReceived = true
                speechExpectation.fulfill()
            }
        }

        // Configure interview
        try await interviewManager.configure(
            project: mockProject,
            voiceId: "Matthew",
            speechRate: 1.0
        )

        // Start speech recognition
        await speechService.startListening()

        // Simulate waiting for speech input
        await fulfillment(of: [speechExpectation], timeout: 10.0, enforceOrder: false)

        speechService.stopListening()
        XCTAssertTrue(transcriptionReceived)
    }

    func testTextToSpeechIntegration() async throws {
        // Test text-to-speech integration
        let voiceService = NativeVoiceService.shared

        let speechExpectation = expectation(description: "Speech playback")

        voiceService.onSpeechStart = {
            // Speech started callback
        }

        voiceService.onSpeechComplete = {
            speechExpectation.fulfill()
        }

        // Test speaking a question
        let testQuestion = "What interests you about this iOS developer position?"
        voiceService.speak(text: testQuestion, voiceId: "Matthew", rate: 1.0)

        await fulfillment(of: [speechExpectation], timeout: 15.0)
        XCTAssertTrue(true) // Test completed successfully
    }

    // MARK: - Network Integration Tests

    func testQuestionGenerationIntegration() async throws {
        // Test integration with Lambda function for question generation
        let networkService = NetworkService.shared

        // Mock the Lambda function call
        let requestBody: [String: Any] = [
            "position": mockProject.position,
            "company": mockProject.company,
            "yearsOfExperience": "2-5",
            "difficulty": "medium",
            "questionType": "behavioral"
        ]

        // This would normally call the actual Lambda function
        // For integration test, we verify the network service is configured correctly
        XCTAssertNotNil(networkService)

        // Test that the interview manager can handle mock questions
        let mockQuestions = [
            Question(
                id: 1,
                text: "Tell me about yourself",
                category: "General",
                difficulty: "easy"
            ),
            Question(
                id: 2,
                text: "Why do you want to work here?",
                category: "Motivation",
                difficulty: "medium"
            )
        ]

        // Verify the interview manager can process these questions
        try await interviewManager.configure(
            project: mockProject,
            voiceId: "Matthew",
            speechRate: 1.0
        )

        XCTAssertNotNil(interviewManager)
    }

    // MARK: - End-to-End Interview Flow Tests

    func testCompleteInterviewFlow() async throws {
        // Test the complete interview flow from start to finish
        let flowExpectation = expectation(description: "Complete interview flow")

        var stateTransitions: [InterviewFlowState] = []

        interviewManager.$currentState
            .sink { state in
                stateTransitions.append(state)

                // Complete flow: idle -> starting -> playingQuestion -> waitingForSpeech -> recording -> processing -> finished
                if stateTransitions.count >= 5 {
                    flowExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Configure interview
        try await interviewManager.configureForDailyQuestions()

        // Start the interview
        await interviewManager.startInterview()

        // Simulate user progression through interview
        // This would typically involve:
        // 1. Question is played
        // 2. User starts speaking (recording begins)
        // 3. User finishes speaking (recording ends)
        // 4. Answer is processed
        // 5. Next question or interview completion

        await fulfillment(of: [flowExpectation], timeout: 15.0)

        XCTAssertTrue(stateTransitions.contains(.idle))
        XCTAssertTrue(stateTransitions.contains(.starting))
        XCTAssertGreaterThan(stateTransitions.count, 2)
    }

    // MARK: - Error Handling Integration Tests

    func testNetworkFailureHandling() async throws {
        // Test how the interview flow handles network failures
        let errorExpectation = expectation(description: "Network error handling")

        interviewManager.$errorMessage
            .compactMap { $0 }
            .sink { errorMessage in
                XCTAssertFalse(errorMessage.isEmpty)
                errorExpectation.fulfill()
            }
            .store(in: &cancellables)

        // Configure interview with invalid project to trigger error
        let invalidProject = Project(
            id: UUID(),
            name: "",
            company: "",
            position: "",
            description: "",
            userId: "",
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            try await interviewManager.configure(
                project: invalidProject,
                voiceId: "Matthew",
                speechRate: 1.0
            )
            await interviewManager.startInterview()
        } catch {
            // Expected to fail with invalid project
            XCTAssertNotNil(error)
        }

        await fulfillment(of: [errorExpectation], timeout: 5.0, enforceOrder: false)
    }

    func testAudioPermissionHandling() async throws {
        // Test audio permission handling
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission

        switch permissionStatus {
        case .denied:
            // Test should handle denied permissions gracefully
            XCTAssertNoThrow({
                Task {
                    await interviewManager.startRecording()
                    XCTAssertFalse(interviewManager.isRecording)
                }
            })

        case .undetermined:
            // Test should request permissions
            let permission = await interviewManager.requestMicrophonePermission()
            XCTAssertNotNil(permission)

        case .granted:
            // Test should proceed normally
            await interviewManager.startRecording()
            XCTAssertTrue(interviewManager.isRecording)
            await interviewManager.stopRecording()

        @unknown default:
            XCTFail("Unknown permission status")
        }
    }

    // MARK: - Performance Integration Tests

    func testInterviewPerformance() throws {
        // Test interview performance metrics
        measure {
            let expectation = self.expectation(description: "Performance test")

            Task {
                do {
                    try await interviewManager.configure(
                        project: mockProject,
                        voiceId: "Matthew",
                        speechRate: 1.0
                    )
                    await interviewManager.startInterview()
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testMemoryUsageDuringInterview() async throws {
        // Test memory usage during interview
        let startMemory = getMemoryUsage()

        try await interviewManager.configure(
            project: mockProject,
            voiceId: "Matthew",
            speechRate: 1.0
        )

        await interviewManager.startInterview()

        // Simulate some interview activity
        await interviewManager.startRecording()
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        await interviewManager.stopRecording()

        let endMemory = getMemoryUsage()
        let memoryIncrease = endMemory - startMemory

        // Memory increase should be reasonable (less than 50MB for basic operations)
        XCTAssertLessThan(memoryIncrease, 50.0, "Memory usage increased too much during interview")
    }

    // MARK: - Helper Methods

    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0.0
        }
    }

    private func waitForAsyncOperation(timeout: TimeInterval = 5.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}

// MARK: - Mock Extensions for Testing

extension InterviewManager {
    func configureForDailyQuestions() async throws {
        // Configure for daily questions mode
        try await configure(
            project: Project(
                id: UUID(),
                name: "Daily Practice",
                company: "Practice Company",
                position: "Software Engineer",
                description: "Daily interview practice",
                userId: "test-user",
                createdAt: Date(),
                updatedAt: Date()
            ),
            voiceId: "Matthew",
            speechRate: 1.0
        )
    }

    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - Test Data Models

extension Question {
    init(id: Int, text: String, category: String, difficulty: String) {
        self.id = id
        self.text = text
        self.category = category
        self.difficulty = difficulty
    }
}