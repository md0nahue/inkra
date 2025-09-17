import Foundation
import AVFoundation

enum AudioPlaybackError: Error {
    case failedToCreatePlayer
}

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class AudioPlaybackService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var playbackRate: Float = 1.0
    
    private var audioPlayer: AVPlayer?
    private var currentPlayerItem: AVPlayerItem?
    private var timer: Timer?
    private var currentAudioSegmentId: String?
    private let audioCache = AudioCacheService.shared
    
    static let shared = AudioPlaybackService()
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func playAudio(from url: URL, audioSegmentId: String) async {
        await playAudioInternal(from: url, identifier: audioSegmentId, cacheKey: .audioSegmentId(Int(audioSegmentId)))
    }
    
    func playAudio(from url: URL, questionId: Int) async {
        await playAudioInternal(from: url, identifier: String(questionId), cacheKey: .questionId(questionId))
    }
    
    func playAudio(from url: URL, vibeLogEntryId: Int) async {
        await playAudioInternal(from: url, identifier: String(vibeLogEntryId), cacheKey: .vibeLogEntryId(vibeLogEntryId))
    }
    
    private enum CacheKey {
        case audioSegmentId(Int?)
        case questionId(Int)
        case vibeLogEntryId(Int)
    }
    
    private func playAudioInternal(from url: URL, identifier: String, cacheKey: CacheKey) async {
        // Stop current playback if playing a different segment
        if currentAudioSegmentId != identifier {
            stopPlayback()
        }
        
        currentAudioSegmentId = identifier
        isLoading = true
        errorMessage = nil
        
        do {
            var finalURL: URL
            var cachedData: Data?
            
            // Try to get from cache first based on cache key type
            switch cacheKey {
            case .audioSegmentId(let segmentId):
                if let id = segmentId {
                    cachedData = audioCache.getCachedAudioData(audioSegmentId: id)
                }
            case .questionId(let questionId):
                cachedData = audioCache.getCachedAudioData(questionId: questionId)
            case .vibeLogEntryId(let entryId):
                cachedData = audioCache.getCachedAudioData(vibeLogEntryId: entryId)
            }
            
            if let cached = cachedData {
                print("🎵 Using cached audio for identifier \(identifier)")
                // Create temporary file from cached data for AVPlayer
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("temp_audio_\(identifier)")
                    .appendingPathExtension("mp3")
                
                try cached.write(to: tempURL)
                finalURL = tempURL
            } else {
                // Download audio data if not in cache
                print("📥 Downloading audio for identifier \(identifier)")
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // Cache the downloaded data for future use
                switch cacheKey {
                case .audioSegmentId(let segmentId):
                    if let id = segmentId {
                        audioCache.cacheAudioData(data, audioSegmentId: id)
                    }
                case .questionId(let questionId):
                    audioCache.cacheAudioData(data, questionId: questionId)
                case .vibeLogEntryId(let entryId):
                    audioCache.cacheAudioData(data, vibeLogEntryId: entryId)
                }
                
                // Create temporary file from downloaded data for AVPlayer
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("temp_audio_\(identifier)")
                    .appendingPathExtension("mp3")
                
                try data.write(to: tempURL)
                finalURL = tempURL
            }
            
            // Create AVPlayer with the audio file
            currentPlayerItem = AVPlayerItem(url: finalURL)
            audioPlayer = AVPlayer(playerItem: currentPlayerItem)
            
            // Set up observers for playback completion
            setupPlayerObservers()
            
            // Wait for player item to be ready
            guard let playerItem = currentPlayerItem else {
                throw AudioPlaybackError.failedToCreatePlayer
            }
            
            // Get duration once the player item is ready
            if playerItem.duration.isValid && !playerItem.duration.isIndefinite {
                duration = CMTimeGetSeconds(playerItem.duration)
            } else {
                duration = 0
            }
            
            // Apply playback rate and start playback
            audioPlayer?.rate = playbackRate
            audioPlayer?.play()
            isPlaying = true
            startTimer()
            
        } catch {
            errorMessage = "Failed to load audio: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func resumePlayback() {
        guard let player = audioPlayer else { return }
        player.rate = playbackRate // Ensure rate is maintained when resuming
        player.play()
        isPlaying = true
        startTimer()
    }
    
    func stopPlayback() {
        removePlayerObservers()
        audioPlayer?.pause()
        audioPlayer = nil
        currentPlayerItem = nil
        isPlaying = false
        currentTime = 0
        currentAudioSegmentId = nil
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        audioPlayer?.seek(to: cmTime)
        currentTime = time
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentTime() {
        guard let player = audioPlayer else {
            currentTime = 0
            return
        }
        
        let currentCMTime = player.currentTime()
        if currentCMTime.isValid && !currentCMTime.isIndefinite {
            currentTime = CMTimeGetSeconds(currentCMTime)
        }
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        audioPlayer?.rate = rate
    }
    
    private func setupPlayerObservers() {
        guard let currentPlayerItem = currentPlayerItem else { return }
        
        // Remove any existing observers first
        removePlayerObservers()
        
        // Listen for playback completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: currentPlayerItem
        )
        
        print("🎵👂 DEBUG: Added observer for player item: \(currentPlayerItem)")
    }
    
    private func removePlayerObservers() {
        // Remove observers for the specific player item if it exists
        if let currentPlayerItem = currentPlayerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentPlayerItem)
            print("🎵🚫 DEBUG: Removed observer for player item: \(currentPlayerItem)")
        } else {
            // Fallback: remove all observers for this notification
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            print("🎵🚫 DEBUG: Removed all AVPlayerItemDidPlayToEndTime observers")
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        print("🎵✅ DEBUG: playerDidFinishPlaying called")
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }
    
    var isCurrentSegment: (String) -> Bool {
        { segmentId in
            self.currentAudioSegmentId == segmentId
        }
    }
}