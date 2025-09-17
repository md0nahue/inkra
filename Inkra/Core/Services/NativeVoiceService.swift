import Foundation
import AVFoundation
import UIKit

@MainActor
class NativeVoiceService: NSObject, ObservableObject {
    static let shared = NativeVoiceService()

    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentUtteranceId: String?
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    @Published var selectedVoice: AVSpeechSynthesisVoice?

    // MARK: - Speech Synthesis Components
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var utteranceQueue: [AVSpeechUtterance] = []
    private var utteranceMap: [AVSpeechUtterance: String] = [:]

    // MARK: - Configuration (V1: Made public for simplicity)
    public var speechRate: Float = 0.5
    public var pitchMultiplier: Float = 1.0
    public var volume: Float = 1.0
    private var preUtteranceDelay: TimeInterval = 0.0
    private var postUtteranceDelay: TimeInterval = 0.0

    // MARK: - Callbacks
    var onSpeechStarted: ((String) -> Void)?
    var onSpeechFinished: ((String) -> Void)?
    var onSpeechCancelled: ((String) -> Void)?
    var onSpeechPaused: (() -> Void)?
    var onSpeechResumed: (() -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Reference for AI voice coordination
    weak var audioRecorder: AudioRecorder?

    private override init() {
        super.init()
        setupSpeechSynthesizer()
        loadAvailableVoices()
        setupAudioSession()
    }

    // MARK: - Setup
    private func setupSpeechSynthesizer() {
        speechSynthesizer.delegate = self
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
            onError?(VoiceError.audioSessionError(error))
        }
    }

    private func loadAvailableVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in
                // Filter for high-quality voices and common languages
                voice.language.hasPrefix("en") ||
                voice.language.hasPrefix("es") ||
                voice.language.hasPrefix("fr") ||
                voice.language.hasPrefix("de") ||
                voice.language.hasPrefix("it") ||
                voice.language.hasPrefix("pt")
            }
            .sorted { voice1, voice2 in
                // Sort by quality (enhanced > premium > compact), then by language
                let quality1 = voice1.quality.rawValue
                let quality2 = voice2.quality.rawValue

                if quality1 != quality2 {
                    return quality1 > quality2
                }
                return voice1.language < voice2.language
            }

        // Set default voice to the first high-quality English voice
        selectedVoice = availableVoices.first { voice in
            voice.language.hasPrefix("en") && voice.quality == .enhanced
        } ?? availableVoices.first { voice in
            voice.language.hasPrefix("en")
        } ?? availableVoices.first

        print("🗣️ Loaded \(availableVoices.count) available voices")
        if let defaultVoice = selectedVoice {
            print("🎯 Default voice: \(defaultVoice.name) (\(defaultVoice.language))")
        }
    }

    // MARK: - Public Methods
    func speak(text: String, utteranceId: String? = nil) {
        let id = utteranceId ?? UUID().uuidString

        print("🗣️ Speaking text: \"\(text)\" with ID: \(id)")

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = speechRate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = volume
        utterance.preUtteranceDelay = preUtteranceDelay
        utterance.postUtteranceDelay = postUtteranceDelay

        // Map utterance to ID for tracking
        utteranceMap[utterance] = id
        utteranceQueue.append(utterance)

        // Notify audio recorder that AI voice is starting
        audioRecorder?.setAIVoicePlayingStatus(true)

        speechSynthesizer.speak(utterance)
    }

    func stopSpeaking() {
        print("🛑 Stopping speech synthesis")

        speechSynthesizer.stopSpeaking(at: .immediate)

        // Clear queue and mappings
        utteranceQueue.removeAll()
        utteranceMap.removeAll()

        isPlaying = false
        currentUtteranceId = nil

        // Notify audio recorder that AI voice stopped
        audioRecorder?.setAIVoicePlayingStatus(false)
    }

    func pauseSpeaking() {
        print("⏸️ Pausing speech synthesis")
        speechSynthesizer.pauseSpeaking(at: .immediate)
    }

    func resumeSpeaking() {
        print("▶️ Resuming speech synthesis")
        speechSynthesizer.continueSpeaking()
    }

    // MARK: - Voice Configuration
    func setVoice(_ voice: AVSpeechSynthesisVoice) {
        selectedVoice = voice
        print("🎯 Selected voice: \(voice.name) (\(voice.language))")
    }

    func setVoiceByIdentifier(_ identifier: String) {
        if let voice = availableVoices.first(where: { $0.identifier == identifier }) {
            setVoice(voice)
        } else {
            print("⚠️ Voice with identifier '\(identifier)' not found")
        }
    }

    func setVoiceByLanguage(_ languageCode: String) {
        if let voice = availableVoices.first(where: { $0.language.hasPrefix(languageCode) && $0.quality == .enhanced }) ??
                       availableVoices.first(where: { $0.language.hasPrefix(languageCode) }) {
            setVoice(voice)
        } else {
            print("⚠️ No voice found for language: \(languageCode)")
        }
    }

    // MARK: - Speech Parameters
    func setSpeechRate(_ rate: Float) {
        speechRate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, rate))
        print("🏃 Speech rate set to: \(speechRate)")
    }

    func setPitchMultiplier(_ pitch: Float) {
        pitchMultiplier = max(0.5, min(2.0, pitch))
        print("🎵 Pitch multiplier set to: \(pitchMultiplier)")
    }

    func setVolume(_ vol: Float) {
        volume = max(0.0, min(1.0, vol))
        print("🔊 Volume set to: \(volume)")
    }

    func setUtteranceDelays(preDelay: TimeInterval, postDelay: TimeInterval) {
        preUtteranceDelay = max(0.0, preDelay)
        postUtteranceDelay = max(0.0, postDelay)
        print("⏱️ Utterance delays - pre: \(preUtteranceDelay)s, post: \(postUtteranceDelay)s")
    }

    // MARK: - Voice Information
    func getVoicesForLanguage(_ languageCode: String) -> [AVSpeechSynthesisVoice] {
        return availableVoices.filter { $0.language.hasPrefix(languageCode) }
    }

    func getHighQualityVoices() -> [AVSpeechSynthesisVoice] {
        return availableVoices.filter { $0.quality == .enhanced }
    }

    func getVoiceInfo(for voice: AVSpeechSynthesisVoice) -> VoiceInfo {
        return VoiceInfo(
            identifier: voice.identifier,
            name: voice.name,
            language: voice.language,
            quality: voice.quality,
            gender: voice.gender,
            audioFileSettings: voice.audioFileSettings
        )
    }

    // MARK: - Testing Support
    func previewVoice(_ voice: AVSpeechSynthesisVoice, text: String = "Hello, this is a voice preview.") {
        let previousVoice = selectedVoice
        setVoice(voice)
        speak(text: text, utteranceId: "preview")

        // Restore previous voice after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if let previous = previousVoice {
                self.setVoice(previous)
            }
        }
    }

    // MARK: - State
    var isSpeaking: Bool {
        return speechSynthesizer.isSpeaking
    }

    var isPaused: Bool {
        return speechSynthesizer.isPaused
    }

    var queuedUtterancesCount: Int {
        return utteranceQueue.count
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension NativeVoiceService: @preconcurrency AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isPlaying = true

        if let utteranceId = utteranceMap[utterance] {
            currentUtteranceId = utteranceId
            print("▶️ Started speaking utterance: \(utteranceId)")
            onSpeechStarted?(utteranceId)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let utteranceId = utteranceMap[utterance] {
            print("✅ Finished speaking utterance: \(utteranceId)")
            onSpeechFinished?(utteranceId)

            // Clean up mapping
            utteranceMap.removeValue(forKey: utterance)
        }

        // Remove from queue
        if let index = utteranceQueue.firstIndex(of: utterance) {
            utteranceQueue.remove(at: index)
        }

        // Update state if no more utterances
        if utteranceQueue.isEmpty {
            isPlaying = false
            currentUtteranceId = nil

            // Notify audio recorder that AI voice finished
            audioRecorder?.setAIVoicePlayingStatus(false)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("⏸️ Paused speech synthesis")
        onSpeechPaused?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("▶️ Resumed speech synthesis")
        onSpeechResumed?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if let utteranceId = utteranceMap[utterance] {
            print("❌ Cancelled speaking utterance: \(utteranceId)")
            onSpeechCancelled?(utteranceId)

            // Clean up mapping
            utteranceMap.removeValue(forKey: utterance)
        }

        // Remove from queue
        if let index = utteranceQueue.firstIndex(of: utterance) {
            utteranceQueue.remove(at: index)
        }

        // Update state
        isPlaying = false
        currentUtteranceId = nil

        // Notify audio recorder that AI voice stopped
        audioRecorder?.setAIVoicePlayingStatus(false)
    }
}

// MARK: - Voice Information Model
struct VoiceInfo {
    let identifier: String
    let name: String
    let language: String
    let quality: AVSpeechSynthesisVoiceQuality
    let gender: AVSpeechSynthesisVoiceGender
    let audioFileSettings: [String: Any]?

    var qualityDescription: String {
        switch quality {
        case .default:
            return "Standard"
        case .enhanced:
            return "Enhanced"
        case .premium:
            return "Premium"
        @unknown default:
            return "Unknown"
        }
    }

    var genderDescription: String {
        switch gender {
        case .unspecified:
            return "Unspecified"
        case .male:
            return "Male"
        case .female:
            return "Female"
        @unknown default:
            return "Unknown"
        }
    }

    var languageName: String {
        let locale = Locale(identifier: language)
        return locale.localizedString(forLanguageCode: language) ?? language
    }
}

// MARK: - Error Types
enum VoiceError: LocalizedError {
    case audioSessionError(Error)
    case synthesisError(String)
    case voiceNotAvailable(String)

    var errorDescription: String? {
        switch self {
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        case .synthesisError(let message):
            return "Speech synthesis error: \(message)"
        case .voiceNotAvailable(let voiceIdentifier):
            return "Voice not available: \(voiceIdentifier)"
        }
    }
}