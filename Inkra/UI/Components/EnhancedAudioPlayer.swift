import SwiftUI
import AVFoundation
import Combine

// MARK: - Enhanced Audio Player View

@available(iOS 15.0, macOS 11.0, *)
struct EnhancedAudioPlayer: View {
    @StateObject private var playerManager: EnhancedAudioPlayerManager
    @State private var showingSpeedMenu = false
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0

    let audioSegments: [LocalAudioSegment]
    let waveformStyle: WaveformDisplayStyle

    init(
        audioSegments: [LocalAudioSegment],
        waveformStyle: WaveformDisplayStyle = .overview
    ) {
        self.audioSegments = audioSegments
        self.waveformStyle = waveformStyle
        _playerManager = StateObject(wrappedValue: EnhancedAudioPlayerManager(segments: audioSegments))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Waveform Display with Scrubbing
            waveformSection

            // Playback Controls
            playbackControlsSection

            // Progress and Time Display
            progressSection

            // Advanced Controls
            advancedControlsSection
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            Task {
                await playerManager.loadAudioSegments(audioSegments)
            }
        }
    }

    // MARK: - Waveform Section

    @ViewBuilder
    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Waveform")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if playerManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            ScrubbableWaveformView(
                waveformData: playerManager.waveformData,
                currentTime: playerManager.currentTime,
                duration: playerManager.totalDuration,
                playbackProgress: playerManager.playbackProgress,
                isDragging: $isDragging,
                style: waveformStyle
            ) { newProgress in
                let newTime = newProgress * playerManager.totalDuration
                Task {
                    await playerManager.seek(to: newTime)
                }
            }
            .frame(height: waveformStyle == .detailed ? 120 : 80)
            .overlay(
                // Segment markers
                SegmentMarkersView(
                    segments: audioSegments,
                    totalDuration: playerManager.totalDuration,
                    currentSegment: playerManager.currentSegmentIndex
                ),
                alignment: .bottom
            )
        }
    }

    // MARK: - Playback Controls Section

    @ViewBuilder
    private var playbackControlsSection: some View {
        HStack(spacing: 24) {
            // Skip Backward
            Button {
                Task { await playerManager.skipBackward() }
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .disabled(playerManager.isLoading)

            // Previous Segment
            Button {
                Task { await playerManager.previousSegment() }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .disabled(playerManager.currentSegmentIndex <= 0 || playerManager.isLoading)

            // Play/Pause
            Button {
                Task {
                    if playerManager.isPlaying {
                        await playerManager.pause()
                    } else {
                        await playerManager.play()
                    }
                }
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            .disabled(playerManager.isLoading || audioSegments.isEmpty)

            // Next Segment
            Button {
                Task { await playerManager.nextSegment() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .disabled(playerManager.currentSegmentIndex >= audioSegments.count - 1 || playerManager.isLoading)

            // Skip Forward
            Button {
                Task { await playerManager.skipForward() }
            } label: {
                Image(systemName: "goforward.30")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .disabled(playerManager.isLoading)
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private var progressSection: some View {
        VStack(spacing: 8) {
            // Time Display
            HStack {
                Text(formatTime(playerManager.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Spacer()

                if audioSegments.count > 1 {
                    Text("Segment \(playerManager.currentSegmentIndex + 1) of \(audioSegments.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatTime(playerManager.totalDuration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            // Progress Bar (backup for waveform)
            ProgressView(value: playerManager.playbackProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .opacity(waveformStyle == .none ? 1.0 : 0.3)
        }
    }

    // MARK: - Advanced Controls Section

    @ViewBuilder
    private var advancedControlsSection: some View {
        HStack {
            // Playback Speed
            Menu {
                ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                    Button {
                        Task { await playerManager.setPlaybackSpeed(speed) }
                    } label: {
                        HStack {
                            Text(speed.displayName)
                            if playerManager.currentSpeed == speed {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                    Text(playerManager.currentSpeed.displayName)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            Spacer()

            // Loop Toggle
            Button {
                playerManager.toggleLoop()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: playerManager.isLooping ? "repeat.1" : "repeat")
                    Text("Loop")
                }
                .font(.caption)
                .foregroundColor(playerManager.isLooping ? .blue : .secondary)
            }

            Spacer()

            // Volume Control
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $playerManager.volume, in: 0...1) { _ in
                    Task { await playerManager.updateVolume() }
                }
                .frame(width: 80)
            }
        }

        // Error Message
        if let errorMessage = playerManager.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helper Methods

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Scrubbable Waveform View

struct ScrubbableWaveformView: View {
    let waveformData: [Float]
    let currentTime: TimeInterval
    let duration: TimeInterval
    let playbackProgress: Double
    @Binding var isDragging: Bool
    let style: WaveformDisplayStyle
    let onSeek: (Double) -> Void

    @State private var dragGesture = false
    @State private var tempProgress: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background waveform
                WaveformShape(
                    data: waveformData,
                    style: style
                )
                .fill(Color.gray.opacity(0.3))

                // Played portion
                WaveformShape(
                    data: waveformData,
                    style: style
                )
                .fill(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    Rectangle()
                        .frame(width: geometry.size.width * (dragGesture ? tempProgress : playbackProgress))
                )

                // Playhead
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                    .position(
                        x: geometry.size.width * (dragGesture ? tempProgress : playbackProgress),
                        y: geometry.size.height / 2
                    )

                // Invisible overlay for gestures
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !dragGesture {
                                    dragGesture = true
                                    isDragging = true
                                }

                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                tempProgress = progress
                            }
                            .onEnded { value in
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                onSeek(progress)

                                dragGesture = false
                                isDragging = false
                                tempProgress = 0
                            }
                    )
            }
        }
        .clipped()
    }
}

// MARK: - Waveform Shape

struct WaveformShape: Shape {
    let data: [Float]
    let style: WaveformDisplayStyle

    func path(in rect: CGRect) -> Path {
        guard !data.isEmpty else {
            return Path()
        }

        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2

        switch style {
        case .bars:
            return createBarsPath(in: rect)
        case .continuous, .detailed:
            return createContinuousPath(in: rect)
        case .overview:
            return createOverviewPath(in: rect)
        case .none:
            return Path()
        }
    }

    private func createBarsPath(in rect: CGRect) -> Path {
        var path = Path()
        let barWidth = rect.width / CGFloat(data.count)

        for (index, amplitude) in data.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(amplitude) * rect.height * 0.8
            let barRect = CGRect(
                x: x,
                y: (rect.height - barHeight) / 2,
                width: max(1, barWidth - 1),
                height: barHeight
            )
            path.addRect(barRect)
        }

        return path
    }

    private func createContinuousPath(in rect: CGRect) -> Path {
        var path = Path()
        let stepX = rect.width / CGFloat(max(data.count - 1, 1))
        let midY = rect.height / 2

        // Top line
        for (index, amplitude) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let y = midY - (CGFloat(amplitude) * rect.height * 0.4)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Bottom line (mirrored)
        for (index, amplitude) in data.enumerated().reversed() {
            let x = CGFloat(index) * stepX
            let y = midY + (CGFloat(amplitude) * rect.height * 0.4)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }

    private func createOverviewPath(in rect: CGRect) -> Path {
        var path = Path()
        let stepX = rect.width / CGFloat(max(data.count - 1, 1))
        let midY = rect.height / 2

        for (index, amplitude) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let y = midY - (CGFloat(amplitude) * rect.height * 0.3)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

// MARK: - Segment Markers View

struct SegmentMarkersView: View {
    let segments: [LocalAudioSegment]
    let totalDuration: TimeInterval
    let currentSegment: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Segment separators
                ForEach(Array(segments.prefix(segments.count - 1).enumerated()), id: \.offset) { index, _ in
                    let segmentEndTime = segments.prefix(index + 1).reduce(0) { $0 + $1.duration }
                    let position = totalDuration > 0 ? segmentEndTime / totalDuration : 0
                    let x = geometry.size.width * position

                    Rectangle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: 1)
                        .position(x: x, y: geometry.size.height / 2)
                }

                // Current segment indicator
                HStack(spacing: 4) {
                    ForEach(0..<segments.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentSegment ? Color.blue : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Enhanced Audio Player Manager

@MainActor
class EnhancedAudioPlayerManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var currentSegmentIndex = 0
    @Published var currentSpeed: PlaybackSpeed = .normal
    @Published var isLooping = false
    @Published var volume: Double = 1.0
    @Published var errorMessage: String?
    @Published var waveformData: [Float] = []

    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioSegments: [LocalAudioSegment] = []
    private var segmentStartTimes: [TimeInterval] = []

    // MARK: - Constants
    private let skipBackwardTime: TimeInterval = 15
    private let skipForwardTime: TimeInterval = 30

    init(segments: [LocalAudioSegment]) {
        super.init()
        self.audioSegments = segments
        setupAudioSession()
    }

    deinit {
        timer?.invalidate()
        audioPlayer?.stop()
    }

    // MARK: - Public Methods

    func loadAudioSegments(_ segments: [LocalAudioSegment]) async {
        isLoading = true
        audioSegments = segments
        await generateWaveformData()
        calculateSegmentStartTimes()
        isLoading = false
    }

    func play() async {
        guard !audioSegments.isEmpty else { return }

        if audioPlayer == nil {
            await loadCurrentSegment()
        }

        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    func pause() async {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() async {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        playbackProgress = 0
        isPlaying = false
        stopTimer()
    }

    func seek(to time: TimeInterval) async {
        guard time >= 0 && time <= totalDuration else { return }

        // Find which segment this time belongs to
        let segmentIndex = segmentStartTimes.lastIndex { $0 <= time } ?? 0
        let segmentTime = time - segmentStartTimes[segmentIndex]

        if segmentIndex != currentSegmentIndex {
            currentSegmentIndex = segmentIndex
            await loadCurrentSegment()
        }

        audioPlayer?.currentTime = segmentTime
        currentTime = time
        updateProgress()
    }

    func nextSegment() async {
        guard currentSegmentIndex < audioSegments.count - 1 else { return }
        currentSegmentIndex += 1
        await loadCurrentSegment()
    }

    func previousSegment() async {
        guard currentSegmentIndex > 0 else { return }
        currentSegmentIndex -= 1
        await loadCurrentSegment()
    }

    func skipForward() async {
        let newTime = min(currentTime + skipForwardTime, totalDuration)
        await seek(to: newTime)
    }

    func skipBackward() async {
        let newTime = max(currentTime - skipBackwardTime, 0)
        await seek(to: newTime)
    }

    func setPlaybackSpeed(_ speed: PlaybackSpeed) async {
        currentSpeed = speed
        audioPlayer?.rate = Float(speed.rawValue)
    }

    func toggleLoop() {
        isLooping.toggle()
    }

    func updateVolume() async {
        audioPlayer?.volume = Float(volume)
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        #if canImport(UIKit)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Failed to setup audio session"
        }
        #endif
    }

    private func loadCurrentSegment() async {
        guard currentSegmentIndex < audioSegments.count,
              let url = audioSegments[currentSegmentIndex].localFileURL else {
            errorMessage = "Invalid audio segment"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.rate = Float(currentSpeed.rawValue)
            audioPlayer?.volume = Float(volume)
            audioPlayer?.prepareToPlay()
        } catch {
            errorMessage = "Failed to load audio: \(error.localizedDescription)"
        }
    }

    private func calculateSegmentStartTimes() {
        segmentStartTimes = []
        var cumulativeTime: TimeInterval = 0

        for segment in audioSegments {
            segmentStartTimes.append(cumulativeTime)
            cumulativeTime += segment.duration
        }

        totalDuration = cumulativeTime
    }

    private func generateWaveformData() async {
        var allData: [Float] = []

        for segment in audioSegments {
            guard let url = segment.localFileURL else { continue }

            let asset = AVAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .audio).first else { continue }

            // Generate simplified waveform data
            // In a real implementation, you'd use AVAudioFile and process the audio data
            // For now, we'll simulate waveform data
            let sampleCount = Int(segment.duration * 10) // 10 samples per second
            let segmentData = (0..<sampleCount).map { _ in Float.random(in: 0...1) }
            allData.append(contentsOf: segmentData)
        }

        waveformData = allData
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

        let segmentTime = player.currentTime
        currentTime = segmentStartTimes[currentSegmentIndex] + segmentTime
        updateProgress()

        // Check if current segment finished
        if !player.isPlaying && isPlaying {
            if currentSegmentIndex < audioSegments.count - 1 {
                // Move to next segment
                Task {
                    currentSegmentIndex += 1
                    await loadCurrentSegment()
                    await play()
                }
            } else if isLooping {
                // Loop back to beginning
                Task {
                    currentSegmentIndex = 0
                    await loadCurrentSegment()
                    await play()
                }
            } else {
                // Playback finished
                isPlaying = false
                stopTimer()
            }
        }
    }

    private func updateProgress() {
        playbackProgress = totalDuration > 0 ? currentTime / totalDuration : 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension EnhancedAudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Playback finished with error"
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            errorMessage = "Playback error: \(error?.localizedDescription ?? "Unknown error")"
            isPlaying = false
            stopTimer()
        }
    }
}

// MARK: - Supporting Types

enum PlaybackSpeed: Double, CaseIterable {
    case half = 0.5
    case threeQuarters = 0.75
    case normal = 1.0
    case oneAndQuarter = 1.25
    case oneAndHalf = 1.5
    case double = 2.0

    var displayName: String {
        switch self {
        case .half: return "0.5×"
        case .threeQuarters: return "0.75×"
        case .normal: return "1×"
        case .oneAndQuarter: return "1.25×"
        case .oneAndHalf: return "1.5×"
        case .double: return "2×"
        }
    }
}

enum WaveformDisplayStyle: CaseIterable {
    case none
    case overview
    case bars
    case continuous
    case detailed

    var displayName: String {
        switch self {
        case .none: return "None"
        case .overview: return "Overview"
        case .bars: return "Bars"
        case .continuous: return "Continuous"
        case .detailed: return "Detailed"
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleSegments = [
        LocalAudioSegment(
            questionId: 1,
            fileName: "Question_1.m4a",
            duration: 30.0
        ),
        LocalAudioSegment(
            questionId: 2,
            fileName: "Question_2.m4a",
            duration: 45.0
        )
    ]

    return EnhancedAudioPlayer(
        audioSegments: sampleSegments,
        waveformStyle: .continuous
    )
    .padding()
}