import Foundation
import AVFoundation
import Combine

@available(iOS 15.0, macOS 11.0, *)
@MainActor
protocol AudioPlayerServiceProtocol: ObservableObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var playbackProgress: Double { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func loadAudio(from url: URL) async
    func play() async
    func pause()
    func stop()
    func seek(to time: TimeInterval)
}

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class AudioPlayerService: NSObject, AudioPlayerServiceProtocol {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    #if canImport(UIKit)
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    #endif
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        audioPlayer?.stop()
        timer?.invalidate()
    }
    
    private func setupAudioSession() {
        #if canImport(UIKit)
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            errorMessage = "Failed to set up audio session"
        }
        #endif
    }
    
    func loadAudio(from url: URL) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Download audio data
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Create audio player
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.prepareToPlay()
            
            await MainActor.run {
                self.audioPlayer = player
                self.duration = player.duration
                self.currentTime = 0
                self.playbackProgress = 0
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load audio: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func play() async {
        guard let player = audioPlayer else {
            errorMessage = "No audio loaded"
            return
        }
        
        guard !isPlaying else { return }
        
        do {
            #if canImport(UIKit)
            try audioSession.setActive(true)
            #endif
            player.play()
            isPlaying = true
            startTimer()
        } catch {
            errorMessage = "Failed to start playback: \(error.localizedDescription)"
        }
    }
    
    func pause() {
        guard let player = audioPlayer else { return }
        guard isPlaying else { return }
        
        player.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        guard let player = audioPlayer else { return }
        
        player.stop()
        player.currentTime = 0
        currentTime = 0
        playbackProgress = 0
        isPlaying = false
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        guard time >= 0 && time <= duration else { return }
        
        player.currentTime = time
        currentTime = time
        updateProgress()
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlaybackState()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updatePlaybackState() {
        guard let player = audioPlayer else { return }
        
        currentTime = player.currentTime
        updateProgress()
        
        // Check if playback finished
        if !player.isPlaying && isPlaying && currentTime >= duration - 0.1 {
            isPlaying = false
            stopTimer()
        }
    }
    
    private func updateProgress() {
        if duration > 0 {
            playbackProgress = currentTime / duration
        } else {
            playbackProgress = 0
        }
    }
    
    // Format time for display
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioPlayerDelegate
@available(iOS 15.0, macOS 11.0, *)
extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.stopTimer()
            
            if flag {
                self.currentTime = self.duration
                self.playbackProgress = 1.0
            } else {
                self.errorMessage = "Playback finished with error"
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isPlaying = false
            self.stopTimer()
            self.errorMessage = "Playback error: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}