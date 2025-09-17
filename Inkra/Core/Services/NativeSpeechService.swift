import Foundation
import Speech
import AVFoundation

@MainActor
class NativeSpeechService: NSObject, ObservableObject {
    static let shared = NativeSpeechService()

    // MARK: - Published Properties
    @Published var isListening = false
    @Published var transcriptionText = ""
    @Published var errorMessage: String?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Speech Recognition Components
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    // MARK: - Configuration
    private var speechTimeout: TimeInterval = 1.5
    private var autoSubmitEnabled = true
    private var silenceTimer: Timer?

    // MARK: - Callbacks
    var onTranscriptionUpdate: ((String) -> Void)?
    var onFinalTranscription: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private override init() {
        super.init()
        setupSpeechRecognizer()
        requestSpeechAuthorization()
    }

    // MARK: - Setup
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self

        if speechRecognizer?.isAvailable != true {
            print("⚠️ Speech recognition not available on this device")
            errorMessage = "Speech recognition not available on this device"
        }
    }

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status

                switch status {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied:
                    print("❌ Speech recognition denied")
                    self?.errorMessage = "Speech recognition access denied"
                case .restricted:
                    print("❌ Speech recognition restricted")
                    self?.errorMessage = "Speech recognition is restricted on this device"
                case .notDetermined:
                    print("❓ Speech recognition authorization not determined")
                @unknown default:
                    print("❓ Unknown speech recognition authorization status")
                }
            }
        }
    }

    // MARK: - Public Methods
    func startListening() throws {
        guard authorizationStatus == .authorized else {
            throw SpeechError.notAuthorized
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerNotAvailable
        }

        // Stop any previous session
        stopListening()

        // Configure audio session
        try configureAudioSession()

        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.unableToCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handleRecognitionResult(result: result, error: error)
            }
        }

        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        transcriptionText = ""
        errorMessage = nil

        print("🎙️ Started native speech recognition")
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false

        print("🛑 Stopped native speech recognition")
    }

    func pauseListening() {
        guard isListening else { return }

        audioEngine.pause()
        print("⏸️ Paused native speech recognition")
    }

    func resumeListening() {
        guard isListening else { return }

        do {
            try audioEngine.start()
            print("▶️ Resumed native speech recognition")
        } catch {
            print("❌ Failed to resume speech recognition: \(error)")
            onError?(error)
        }
    }

    // MARK: - Configuration
    func setSpeechTimeout(_ timeout: TimeInterval) {
        speechTimeout = timeout
    }

    func setAutoSubmitEnabled(_ enabled: Bool) {
        autoSubmitEnabled = enabled
    }

    func setLanguage(_ languageCode: String) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
        speechRecognizer?.delegate = self

        if speechRecognizer?.isAvailable != true {
            print("⚠️ Speech recognition not available for language: \(languageCode)")
            errorMessage = "Speech recognition not available for this language"
        }
    }

    // MARK: - Private Methods
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("❌ Speech recognition error: \(error)")
            self.errorMessage = error.localizedDescription
            onError?(error)
            stopListening()
            return
        }

        guard let result = result else { return }

        let transcription = result.bestTranscription.formattedString
        transcriptionText = transcription
        onTranscriptionUpdate?(transcription)

        // Reset silence timer on new speech
        resetSilenceTimer()

        if result.isFinal {
            print("✅ Final transcription: \(transcription)")
            onFinalTranscription?(transcription)

            if autoSubmitEnabled {
                stopListening()
            }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()

        guard autoSubmitEnabled else { return }

        silenceTimer = Timer.scheduledTimer(withTimeInterval: speechTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, self.isListening else { return }

                print("⏰ Speech timeout reached, stopping recognition")

                if !self.transcriptionText.isEmpty {
                    self.onFinalTranscription?(self.transcriptionText)
                }

                self.stopListening()
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension NativeSpeechService: @preconcurrency SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if available {
                print("✅ Speech recognizer became available")
                self.errorMessage = nil
            } else {
                print("❌ Speech recognizer became unavailable")
                self.errorMessage = "Speech recognition temporarily unavailable"
                self.stopListening()
            }
        }
    }
}

// MARK: - Error Types
enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case unableToCreateRequest
    case audioEngineError

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .recognizerNotAvailable:
            return "Speech recognition is not available on this device."
        case .unableToCreateRequest:
            return "Unable to create speech recognition request."
        case .audioEngineError:
            return "Audio engine configuration failed."
        }
    }
}

// MARK: - Permission Helper
extension NativeSpeechService {
    var isAuthorized: Bool {
        return authorizationStatus == .authorized
    }

    var canRecord: Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}