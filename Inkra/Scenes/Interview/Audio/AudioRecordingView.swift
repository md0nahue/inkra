import SwiftUI
import AVKit

@available(iOS 15.0, macOS 11.0, *)
struct AudioRecordingView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    let question: Question?
    let questionState: QuestionState
    let onRecordingComplete: (URL, TimeInterval) -> Void
    let onExplicitStop: (() -> Void)?
    let existingRecordingURL: URL?
    let isSpeechInterview: Bool
    @State private var showingPermissionAlert = false
    @State private var recordingURL: URL?
    
    
    // Initialize with external AudioRecorder
    init(audioRecorder: AudioRecorder, question: Question?, questionState: QuestionState = .readyToRecord, existingRecordingURL: URL? = nil, isSpeechInterview: Bool = false, onRecordingComplete: @escaping (URL, TimeInterval) -> Void, onExplicitStop: (() -> Void)? = nil) {
        self.audioRecorder = audioRecorder
        self.question = question
        self.questionState = questionState
        self.existingRecordingURL = existingRecordingURL
        self.isSpeechInterview = isSpeechInterview
        self.onRecordingComplete = onRecordingComplete
        self.onExplicitStop = onExplicitStop
    }
    
    var body: some View {
        VStack(spacing: 40) { // Adjusted spacing for better layout
            waveformSection
            
            // Only show recording controls if not in speech interview mode
            if !isSpeechInterview {
                recordingControls
            } else {
                // Show hands-free mode indicator with no manual controls
                handsFreeIndicator
            }
            
            if recordingURL != nil || existingRecordingURL != nil {
                Spacer().frame(height: 20) // Additional space before playback controls
                playbackControls
            }
            
            if audioRecorder.recordingDuration > 0 {
                durationSection
            }
        }
        .padding()
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable microphone access in Settings to record audio.")
        }
        .alert("Recording Error", isPresented: .constant(audioRecorder.errorMessage != nil)) {
            Button("OK") {
                audioRecorder.errorMessage = nil
            }
        } message: {
            Text(audioRecorder.errorMessage ?? "")
        }
        .onAppear {
            if !audioRecorder.permissionGranted {
                audioRecorder.requestPermission()
            }
        }
        .onChange(of: audioRecorder.permissionGranted) { granted in
            if !granted {
                showingPermissionAlert = true
            }
        }
    }
    
    private func questionSection(_ question: Question) -> some View {
        VStack(spacing: 12) {
            if question.isFollowUp {
                Text("Follow-up question")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(question.text)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var waveformSection: some View {
        VStack(spacing: 16) {
            if recordingURL != nil || existingRecordingURL != nil {
                // Show simple talking indicator when recording exists
                TalkingIndicator(
                    state: .idle,
                    size: 80
                )
            } else if isSpeechInterview {
                // Use simple talking indicator for speech interviews
                TalkingIndicator(
                    state: audioRecorder.isRecording ? .speaking : .idle,
                    size: 80
                )
            } else {
                // Use simple talking indicator for all interview types  
                TalkingIndicator(
                    state: audioRecorder.isRecording ? .speaking : .idle,
                    size: 80
                )
            }
            
            statusMessageView
        }
        .frame(height: isSpeechInterview ? 120 : 80)
    }
    
    private var statusMessageView: some View {
        Group {
            if audioRecorder.isRecording {
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                            .scaleEffect(audioRecorder.isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: audioRecorder.isRecording)
                        
                        Text("RECORDING!")
                            .font(.headline)
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }
                    
                    Text("STOP RECORDING")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            } else if audioRecorder.isPlaying {
                Text("Playing...")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            } else {
                switch questionState {
                case .readyToRecord:
                    Text("Tap to record")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                case .recorded:
                    Text("Recording saved")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                case .skipped:
                    Text("Question skipped")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                case .recordingActive:
                    Text("Recording...")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    private var recordingControls: some View {
        HStack(spacing: 24) {
            if audioRecorder.isRecording {
                Button {
                    stopRecording()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    startRecording()
                } label: {
                    let (iconName, color) = getRecordButtonAppearance()
                    Image(systemName: iconName)
                        .font(.system(size: 64))
                        .foregroundColor(color)
                }
                .buttonStyle(.plain)
                .disabled(!audioRecorder.permissionGranted)
            }
        }
    }
    
    private func getRecordButtonAppearance() -> (String, Color) {
        if !audioRecorder.permissionGranted {
            return ("record.circle.fill", .gray)
        }
        
        switch questionState {
        case .readyToRecord:
            return ("record.circle.fill", .red)
        case .recorded:
            return ("arrow.clockwise.circle.fill", .blue)
        case .skipped:
            return ("record.circle.fill", .orange)
        case .recordingActive:
            return ("record.circle.fill", .red)
        }
    }
    
    private var playbackControls: some View {
        HStack(spacing: 24) {
            Button {
                if audioRecorder.isPlaying {
                    audioRecorder.stopPlayback()
                } else {
                    // Use the existing recording URL if available, otherwise use the current recording
                    let urlToPlay = existingRecordingURL ?? recordingURL
                    audioRecorder.playRecording(from: urlToPlay)
                }
            } label: {
                Image(systemName: audioRecorder.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(audioRecorder.isRecording ? .gray : .blue)
            }
            .buttonStyle(.plain)
            .disabled(audioRecorder.isRecording)
            
            Button {
                // Only delete if it's a new recording, not an existing one
                if recordingURL != nil {
                    audioRecorder.deleteRecording()
                    recordingURL = nil
                }
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            
        }
    }
    
    private var durationSection: some View {
        VStack(spacing: 8) {
            Text(audioRecorder.formatDuration(audioRecorder.recordingDuration))
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
            
            Text("Duration")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var handsFreeIndicator: some View {
        VStack(spacing: 12) {
            // Animated microphone icon
            ZStack {
                Circle()
                    .fill(audioRecorder.isRecording ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .scaleEffect(audioRecorder.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: audioRecorder.isRecording)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(audioRecorder.isRecording ? .red : .gray)
            }
            
            VStack(spacing: 4) {
                Text("Hands-Free Mode Active")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(audioRecorder.isRecording ? "Listening..." : "Preparing...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if audioRecorder.isRecording {
                    Text("Speak clearly, then pause when done")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private func startRecording() {
        guard audioRecorder.permissionGranted else {
            showingPermissionAlert = true
            return
        }
        
        Task {
            recordingURL = await audioRecorder.startRecording()
        }
    }
    
    private func stopRecording() {
        // Call the explicit stop callback if provided, otherwise handle locally
        if let onExplicitStop = onExplicitStop {
            onExplicitStop()
        } else {
            recordingURL = audioRecorder.stopRecording()
            
            // Automatically trigger completion callback when recording stops
            if let url = recordingURL {
                onRecordingComplete(url, audioRecorder.recordingDuration)
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    AudioRecordingView(
        audioRecorder: AudioRecorder(),
        question: Question(questionId: 1, text: "What is your story about?", order: 1, omitted: false),
        questionState: .readyToRecord,
        existingRecordingURL: nil,
        onRecordingComplete: { url, duration in
            print("Recording complete: \(url), Duration: \(duration)")
        },
        onExplicitStop: {
            print("Explicit stop")
        }
    )
}