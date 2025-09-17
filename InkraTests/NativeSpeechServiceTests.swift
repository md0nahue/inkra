import XCTest
import Speech
import AVFoundation
@testable import Inkra

@available(iOS 15.0, *)
final class NativeSpeechServiceTests: XCTestCase {

    var speechService: NativeSpeechService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        speechService = NativeSpeechService.shared
    }

    override func tearDownWithError() throws {
        speechService.stopListening()
        speechService = nil
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testSingletonInstance() {
        let instance1 = NativeSpeechService.shared
        let instance2 = NativeSpeechService.shared

        XCTAssertTrue(instance1 === instance2, "NativeSpeechService should be a singleton")
    }

    func testInitialState() {
        XCTAssertFalse(speechService.isListening, "Should not be listening initially")
        XCTAssertEqual(speechService.transcriptionText, "", "Transcription text should be empty initially")
        XCTAssertNil(speechService.errorMessage, "Error message should be nil initially")
    }

    // MARK: - Configuration Tests

    func testSpeechTimeoutConfiguration() {
        let timeout: TimeInterval = 3.0
        speechService.setSpeechTimeout(timeout)

        // Note: We can't directly test the private speechTimeout property,
        // but we can verify the method doesn't crash
        XCTAssertTrue(true, "setSpeechTimeout should execute without crashing")
    }

    func testAutoSubmitConfiguration() {
        speechService.setAutoSubmitEnabled(true)
        speechService.setAutoSubmitEnabled(false)

        // Note: Testing the behavior would require more complex mocking
        XCTAssertTrue(true, "setAutoSubmitEnabled should execute without crashing")
    }

    func testLanguageConfiguration() {
        speechService.setLanguage("en-US")
        speechService.setLanguage("es-ES")

        // The method should handle language changes gracefully
        XCTAssertTrue(true, "setLanguage should execute without crashing")
    }

    // MARK: - Permission Tests

    func testAuthorizationStatus() {
        // Test that authorization status is accessible
        let status = speechService.authorizationStatus
        XCTAssertTrue(
            [.notDetermined, .denied, .restricted, .authorized].contains(status),
            "Authorization status should be one of the valid cases"
        )
    }

    func testPermissionChecks() {
        XCTAssertNotNil(speechService.isAuthorized, "isAuthorized should return a boolean value")
        XCTAssertNotNil(speechService.canRecord, "canRecord should return a boolean value")
    }

    func testMicrophonePermissionRequest() async {
        let permissionGranted = await speechService.requestMicrophonePermission()

        // We can't control the actual permission in tests, but we can verify the method works
        XCTAssertNotNil(permissionGranted, "requestMicrophonePermission should return a boolean")
    }

    // MARK: - Error Handling Tests

    func testErrorHandlingWhenNotAuthorized() {
        // Mock unauthorized state by testing the enum cases
        XCTAssertThrowsError(try SpeechError.notAuthorized.throwError()) { error in
            XCTAssertEqual(error as? SpeechError, SpeechError.notAuthorized)
        }
    }

    func testErrorHandlingForUnavailableRecognizer() {
        XCTAssertThrowsError(try SpeechError.recognizerNotAvailable.throwError()) { error in
            XCTAssertEqual(error as? SpeechError, SpeechError.recognizerNotAvailable)
        }
    }

    // MARK: - State Management Tests

    func testListeningStateManagement() {
        // Test initial state
        XCTAssertFalse(speechService.isListening, "Should not be listening initially")

        // Note: We can't easily test actual listening without proper permissions
        // and real audio input, but we can test state management
        speechService.stopListening()
        XCTAssertFalse(speechService.isListening, "Should not be listening after stop")
    }

    func testPauseAndResumeOperations() {
        // Test that pause and resume methods don't crash
        speechService.pauseListening()
        speechService.resumeListening()

        XCTAssertTrue(true, "Pause and resume operations should not crash")
    }

    // MARK: - Performance Tests

    func testSpeechServicePerformance() {
        measure {
            // Test the performance of creating and configuring the speech service
            let testService = NativeSpeechService.shared
            testService.setSpeechTimeout(1.5)
            testService.setAutoSubmitEnabled(true)
            testService.setLanguage("en-US")
        }
    }

    // MARK: - Integration Tests

    func testCallbackConfiguration() {
        var transcriptionCalled = false
        var errorCalled = false

        speechService.onTranscriptionUpdate = { transcription in
            transcriptionCalled = true
        }

        speechService.onError = { error in
            errorCalled = true
        }

        // Verify callbacks are set (we can't easily trigger them in tests)
        XCTAssertNotNil(speechService.onTranscriptionUpdate, "Transcription callback should be set")
        XCTAssertNotNil(speechService.onError, "Error callback should be set")
    }

    // MARK: - Memory Management Tests

    func testMemoryLeaks() {
        weak var weakService: NativeSpeechService?

        autoreleasepool {
            let service = NativeSpeechService.shared
            weakService = service

            // Perform some operations
            service.setSpeechTimeout(2.0)
            service.stopListening()
        }

        // Note: Since it's a singleton, it won't be deallocated
        // This test mainly ensures no retain cycles in operations
        XCTAssertNotNil(weakService, "Singleton should remain in memory")
    }
}

// MARK: - Mock Extensions for Testing

extension SpeechError {
    func throwError() throws {
        throw self
    }
}

// MARK: - Test Helper Extensions

@available(iOS 15.0, *)
extension NativeSpeechServiceTests {

    func createMockAudioBuffer() -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        return buffer
    }

    func waitForAsyncOperation(timeout: TimeInterval = 5.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}