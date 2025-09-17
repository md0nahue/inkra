import SwiftUI
import AVFoundation

@available(iOS 15.0, macOS 11.0, *)
struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isRecording = false
    @State private var hasRecording = false
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showLoadingScreen = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var lastRecordingURL: URL?
    @State private var navigateToPresets = false
    
    let onTopicRecorded: (String) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching main interview screen
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.16),
                        Color(red: 0.12, green: 0.08, blue: 0.20),
                        Color(red: 0.16, green: 0.12, blue: 0.24)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                Spacer()
                
                // Header
                VStack(spacing: 16) {
                    Text("Tell us your story")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Tap to start recording what you'd like to talk about")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Recording status
                if isRecording {
                    VStack(spacing: 12) {
                        Text("Recording...")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(formatDuration(recordingDuration))
                            .font(.system(.title2, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Control buttons
                if !isProcessing {
                    VStack(spacing: 30) {
                        // Main recording button - simplified and clean
                        Button(action: {
                            if isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                
                                if isRecording {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.red.opacity(0.8))
                                } else if hasRecording {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.8))
                                } else {
                                    Image(systemName: "mic")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        
                        // Control buttons when recording exists
                        if hasRecording && !isRecording {
                            HStack(spacing: 40) {
                                // Delete button
                                Button(action: { clearRecording() }) {
                                    Image(systemName: "trash")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.1))
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                }
                                
                                // Submit button
                                Button(action: { submitRecording() }) {
                                    Image(systemName: "checkmark")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(Color.green.opacity(0.2))
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                        
                        Text(isRecording ? "Recording..." : (hasRecording ? "Re-record or Submit" : "Tap to record"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Interview Ideas button
                        Button(action: {
                            navigateToPresets = true
                        }) {
                            Text("Get Interview Ideas")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 25)
                                                .fill(Color.white.opacity(0.1))
                                        )
                                )
                        }
                    }
                }
                
                Spacer()
                }
                .padding()
            }
            .navigationTitle("Spoken Interview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: NavigationLink("Use Text") {
                    TypeYourTopicView { topic in
                        onTopicRecorded(topic)
                    }
                }
            )
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .disabled(isProcessing || showLoadingScreen)
        .sheet(isPresented: $navigateToPresets) {
            PresetTopicsView { selectedTopic in
                navigateToPresets = false
                // Use the selected topic as if it was spoken
                onTopicRecorded(selectedTopic)
            }
        }
        .overlay {
            if showLoadingScreen {
                InterviewCreationLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                    .zIndex(1000)
            }
        }
        .onAppear {
            requestMicrophonePermission()
        }
        .onChange(of: isRecording) { newValue in
            if newValue {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var microphoneColor: Color {
        if isRecording {
            return .red
        } else if hasRecording {
            return ColorTheme.primaryAccent
        } else {
            return ColorTheme.primaryAccent
        }
    }
    
    private func requestMicrophonePermission() {
        audioRecorder.requestPermission()
    }
    
    private func startRecording() {
        guard audioRecorder.permissionGranted else {
            errorMessage = "Microphone permission is required to record audio"
            showError = true
            return
        }
        
        isRecording = true
        recordingDuration = 0
        
        Task {
            let url = await audioRecorder.startRecording()
            if url == nil {
                await MainActor.run {
                    isRecording = false
                    errorMessage = "Failed to start recording"
                    showError = true
                }
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        
        guard let url = audioRecorder.stopRecording() else {
            errorMessage = "No recording to process"
            showError = true
            return
        }
        
        // Minimum recording duration check
        if recordingDuration < 1.0 {
            errorMessage = "Recording too short. Please record for at least 1 second."
            showError = true
            return
        }
        
        // Save the recording URL and mark that we have a recording
        lastRecordingURL = url
        hasRecording = true
    }
    
    private func submitRecording() {
        guard let url = lastRecordingURL else {
            errorMessage = "No recording to submit"
            showError = true
            return
        }
        processAudioFile(url)
    }
    
    private func clearRecording() {
        hasRecording = false
        lastRecordingURL = nil
        recordingDuration = 0
    }
    
    private func processAudioFile(_ url: URL) {
        print("🎤 DEBUG VoiceInputView: Starting processAudioFile")
        print("🎤 DEBUG VoiceInputView: Audio file URL: \(url)")
        
        isProcessing = true
        showLoadingScreen = true
        
        print("🎤 DEBUG VoiceInputView: Set isProcessing=true, showLoadingScreen=true")
        
        Task {
            // TODO: Replace with native iOS SFSpeechRecognizer
            await MainActor.run {
                print("🎤 DEBUG VoiceInputView: Transcription temporarily disabled during migration to native speech")
                showLoadingScreen = false
                isProcessing = false
                errorMessage = "Speech transcription temporarily unavailable during native migration"
                showError = true
            }
        }
    }
    
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    VoiceInputView { topic in
        print("Topic recorded: \(topic)")
    }
}