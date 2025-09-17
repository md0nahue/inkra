import SwiftUI
import AVFoundation
import Combine

// MARK: - Scrolling Waveform View

@available(iOS 15.0, macOS 11.0, *)
struct ScrollingWaveformView: View {
    @StateObject private var waveformManager: WaveformManager

    let style: WaveformStyle
    let height: CGFloat
    let isRecording: Bool

    init(
        audioManager: AudioManager? = nil,
        style: WaveformStyle = .bars,
        height: CGFloat = 120,
        isRecording: Bool = false
    ) {
        _waveformManager = StateObject(wrappedValue: WaveformManager(audioManager: audioManager))
        self.style = style
        self.height = height
        self.isRecording = isRecording
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))

                // Waveform content
                Group {
                    switch style {
                    case .bars:
                        WaveformBarsView(
                            audioLevels: waveformManager.audioLevels,
                            height: height - 16,
                            isRecording: isRecording
                        )
                    case .continuous:
                        WaveformContinuousView(
                            audioLevels: waveformManager.audioLevels,
                            height: height - 16,
                            isRecording: isRecording
                        )
                    case .line:
                        WaveformLineView(
                            audioLevels: waveformManager.audioLevels,
                            height: height - 16,
                            isRecording: isRecording
                        )
                    }
                }
                .padding(8)
                .clipped()

                // Recording indicator
                if isRecording {
                    RecordingIndicator()
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                }
            }
        }
        .frame(height: height)
        .onChange(of: isRecording) { newValue in
            if newValue {
                waveformManager.startCapturing()
            } else {
                waveformManager.stopCapturing()
            }
        }
    }
}

// MARK: - Waveform Manager

@MainActor
class WaveformManager: NSObject, ObservableObject {
    @Published var audioLevels: [Float] = []
    @Published var isCapturing = false

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var timer: Timer?

    private let maxSamples = 150 // Number of samples to keep in rolling buffer
    private let sampleRate = 20.0 // Hz

    private weak var audioManager: AudioManager?

    init(audioManager: AudioManager? = nil) {
        self.audioManager = audioManager
        super.init()
        setupAudioSession()
    }

    deinit {
        stopCapturing()
    }

    private func setupAudioSession() {
        #if canImport(UIKit)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
    }

    func startCapturing() {
        guard !isCapturing else { return }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        inputNode = audioEngine.inputNode
        let recordingFormat = inputNode!.outputFormat(forBus: 0)

        // Install tap to capture audio levels
        inputNode!.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try audioEngine.start()
            isCapturing = true
            startSampleTimer()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stopCapturing() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil

        timer?.invalidate()
        timer = nil

        isCapturing = false
    }

    private func startSampleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / sampleRate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                // Add silence if no recent audio
                if self.audioLevels.last != 0 {
                    self.addAudioLevel(0)
                }
            }
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(
            start: channelDataValue,
            count: Int(buffer.frameLength)
        ))

        // Calculate RMS (Root Mean Square) for amplitude
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))

        Task { @MainActor in
            self.addAudioLevel(rms)
        }
    }

    private func addAudioLevel(_ level: Float) {
        audioLevels.append(level)

        // Keep only the last maxSamples (rolling buffer)
        if audioLevels.count > maxSamples {
            audioLevels.removeFirst()
        }
    }

    func simulateAudioLevels() {
        // For testing without actual audio input
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / sampleRate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                let randomLevel = Float.random(in: 0...0.8)
                self?.addAudioLevel(randomLevel)
            }
        }
    }

    func clearLevels() {
        audioLevels.removeAll()
    }
}

// MARK: - Waveform Styles

enum WaveformStyle: CaseIterable {
    case bars
    case continuous
    case line

    var displayName: String {
        switch self {
        case .bars: return "Bars"
        case .continuous: return "Continuous"
        case .line: return "Line"
        }
    }
}

// MARK: - Waveform Bars View

struct WaveformBarsView: View {
    let audioLevels: [Float]
    let height: CGFloat
    let isRecording: Bool

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2

    var body: some View {
        HStack(alignment: .center, spacing: barSpacing) {
            ForEach(Array(audioLevels.enumerated()), id: \.offset) { index, level in
                WaveformBar(
                    amplitude: CGFloat(level),
                    maxHeight: height,
                    opacity: opacity(for: index, total: audioLevels.count),
                    color: barColor(for: level, isRecording: isRecording)
                )
                .frame(width: barWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func opacity(for index: Int, total: Int) -> Double {
        guard total > 0 else { return 1.0 }
        let position = Double(index) / Double(total)
        return 0.2 + (position * 0.8) // Fade from 20% to 100% opacity
    }

    private func barColor(for level: Float, isRecording: Bool) -> Color {
        if !isRecording {
            return .gray
        }

        if level < 0.1 {
            return .blue.opacity(0.6)
        } else if level < 0.5 {
            return .blue
        } else {
            return .cyan
        }
    }
}

// MARK: - Individual Waveform Bar

struct WaveformBar: View {
    let amplitude: CGFloat
    let maxHeight: CGFloat
    let opacity: Double
    let color: Color

    private let minHeight: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: [color.opacity(opacity), color.opacity(opacity * 0.7)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: max(amplitude * maxHeight * 400, minHeight))
            .animation(.easeOut(duration: 0.1), value: amplitude)
    }
}

// MARK: - Continuous Waveform View

struct WaveformContinuousView: View {
    let audioLevels: [Float]
    let height: CGFloat
    let isRecording: Bool

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !audioLevels.isEmpty else { return }

                let width = geometry.size.width
                let midY = height / 2
                let stepX = width / CGFloat(max(audioLevels.count - 1, 1))

                // Create the top line of the waveform
                for (index, level) in audioLevels.enumerated() {
                    let x = CGFloat(index) * stepX
                    let amplitude = CGFloat(level) * height * 0.4
                    let y = midY - amplitude

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                // Create the bottom line (mirror)
                for (index, level) in audioLevels.enumerated().reversed() {
                    let x = CGFloat(index) * stepX
                    let amplitude = CGFloat(level) * height * 0.4
                    let y = midY + amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: isRecording ?
                        [Color.blue.opacity(0.6), Color.cyan.opacity(0.3)] :
                        [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .animation(.linear(duration: 0.05), value: audioLevels.count)
        }
    }
}

// MARK: - Line Waveform View

struct WaveformLineView: View {
    let audioLevels: [Float]
    let height: CGFloat
    let isRecording: Bool

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !audioLevels.isEmpty else { return }

                let width = geometry.size.width
                let midY = height / 2
                let stepX = width / CGFloat(max(audioLevels.count - 1, 1))

                // Create center line waveform
                for (index, level) in audioLevels.enumerated() {
                    let x = CGFloat(index) * stepX
                    let amplitude = CGFloat(level) * height * 0.4
                    let y = midY - amplitude

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                isRecording ? Color.blue : Color.gray,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .animation(.linear(duration: 0.05), value: audioLevels.count)
        }
    }
}

// MARK: - Recording Indicator

struct RecordingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 3)
                        .scaleEffect(isAnimating ? 1.5 : 1.0)
                        .opacity(isAnimating ? 0.3 : 0.8)
                )
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        isAnimating = true
                    }
                }

            Text("REC")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.red)
        }
    }
}

// MARK: - Preview View

#Preview {
    VStack(spacing: 30) {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bars Style")
                .font(.headline)

            ScrollingWaveformView(
                style: .bars,
                height: 80,
                isRecording: true
            )
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("Continuous Style")
                .font(.headline)

            ScrollingWaveformView(
                style: .continuous,
                height: 80,
                isRecording: true
            )
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("Line Style")
                .font(.headline)

            ScrollingWaveformView(
                style: .line,
                height: 80,
                isRecording: false
            )
        }

        Text("Tap to toggle recording")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(Color.black)
}

// MARK: - Audio Manager Protocol (for external integration)

protocol AudioManager: AnyObject {
    var isRecording: Bool { get }
    var audioLevels: [Float] { get }
}

// MARK: - Integration Helper

extension ScrollingWaveformView {
    static func withLocalAudioManager(_ audioManager: LocalAudioManager) -> some View {
        ScrollingWaveformView(
            audioManager: nil, // We'll connect this in a future version
            style: .bars,
            height: 120,
            isRecording: audioManager.isRecording
        )
    }
}