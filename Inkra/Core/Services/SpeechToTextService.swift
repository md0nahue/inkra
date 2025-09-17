import Foundation
import Speech
import AVFoundation

@available(iOS 15.0, macOS 11.0, *)
class SpeechToTextService: ObservableObject {
    static let shared = SpeechToTextService()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isAuthorized = false
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    
    init() {
        requestTranscriptionPermission()
    }
    
    private func requestTranscriptionPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                self?.isAuthorized = authStatus == .authorized
            }
        }
    }
    
    func startLiveTranscription() {
        guard isAuthorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            return
        }
        
        // Prevent multiple concurrent transcriptions
        guard !isTranscribing else {
            print("Speech recognition already in progress, ignoring start request")
            return
        }
        
        // Stop any ongoing transcription cleanly
        stopTranscription()
        
        // Wait a moment for any previous session to fully clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.performLiveTranscription()
        }
    }
    
    private func performLiveTranscription() {
        do {
            // Configure audio session with conservative settings
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                errorMessage = "Unable to create recognition request"
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            // Set a timeout to prevent hanging
            recognitionRequest.taskHint = .dictation
            
            // Configure audio engine
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Remove any existing tap first
            inputNode.removeTap(onBus: 0)
            
            // Install tap to capture audio
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, when in
                self?.recognitionRequest?.append(buffer)
            }
            
            // Prepare and start audio engine
            audioEngine.prepare()
            try audioEngine.start()
            
            // Start recognition task with error handling
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        let nsError = error as NSError
                        print("Speech recognition error: \(error)")
                        print("Error domain: \(nsError.domain), code: \(nsError.code)")
                        
                        // Handle specific error codes
                        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
                            // This is the specific error we're seeing - usually means multiple recognition attempts
                            self.errorMessage = "Speech recognition service conflict. Retrying..."
                            // Don't immediately retry to avoid rapid fire attempts
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                if !self.isTranscribing {
                                    self.startLiveTranscription()
                                }
                            }
                        } else {
                            self.errorMessage = "Recognition error: \(error.localizedDescription)"
                        }
                        self.stopTranscription()
                        return
                    }
                    
                    if let result = result {
                        self.transcribedText = result.bestTranscription.formattedString
                        
                        if result.isFinal {
                            self.stopTranscription()
                        }
                    }
                }
            }
            
            isTranscribing = true
            errorMessage = nil
            
        } catch {
            errorMessage = "Failed to start live transcription: \(error.localizedDescription)"
            print("Live transcription error: \(error)")
            stopTranscription()
        }
    }
    
    func transcribeAudioFile(url: URL, completion: @escaping (String?) -> Void) {
        guard isAuthorized else {
            completion(nil)
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            completion(nil)
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        isTranscribing = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isTranscribing = false
                
                if let error = error {
                    print("Speech recognition error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let result = result, result.isFinal {
                    completion(result.bestTranscription.formattedString)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    func stopTranscription() {
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Cancel recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isTranscribing = false
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    deinit {
        stopTranscription()
    }
}