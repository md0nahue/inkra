import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct SpeechFirstCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechService = SpeechToTextService.shared
    @StateObject private var viewModel = CreateProjectViewModel()
    @State private var isListening = false
    @State private var showingPermissionAlert = false
    @State private var hasStartedListening = false
    
    let onProjectCreated: (Project) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Sophisticated background
                backgroundGradient
                
                if viewModel.isLoading {
                    // Show loading state when creating project
                    loadingView
                } else {
                    // Main speech input interface
                    mainSpeechInterface
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                requestPermissions()
            }
            .onDisappear {
                cleanupAudio()
            }
            .onChange(of: speechService.transcribedText) { newText in
                handleTranscriptionUpdate(newText)
            }
            .onChange(of: viewModel.createdProject) { project in
                if let project = project {
                    onProjectCreated(project)
                    dismiss()
                }
            }
            .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
                Button("Cancel") {
                    dismiss()
                }
                Button("Settings") {
                    openSettings()
                }
            } message: {
                Text("To use speech input, please enable microphone access in Settings.")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private var backgroundGradient: some View {
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
    }
    
    private var mainSpeechInterface: some View {
        VStack(spacing: 0) {
            // Top spacer
            Spacer()
            
            // Main content area
            VStack(spacing: 40) {
                // Title and instruction
                VStack(spacing: 16) {
                    Text("What do you want to talk about?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Text("Tap the microphone and tell us your story topic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Microphone interface
                microphoneInterface
                
                // Transcription display (if any)
                if !speechService.transcribedText.isEmpty {
                    transcriptionDisplay
                }
            }
            
            Spacer()
            
            // Bottom controls
            bottomControls
        }
    }
    
    private var microphoneInterface: some View {
        VStack(spacing: 20) {
            // Main microphone button
            Button(action: toggleListening) {
                ZStack {
                    // Outer ring
                    Circle()
                        .strokeBorder(microphoneColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 140, height: 140)
                    
                    // Inner fill
                    Circle()
                        .fill(microphoneColor.opacity(isListening ? 0.2 : 0.1))
                        .frame(width: 120, height: 120)
                    
                    // Microphone icon
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(microphoneColor)
                        .scaleEffect(isListening ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isListening)
                }
            }
            .disabled(!speechService.isAuthorized)
            
            // Status text
            Text(statusText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(microphoneColor)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: statusText)
        }
    }
    
    private var transcriptionDisplay: some View {
        VStack(spacing: 12) {
            Text("You said:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            ScrollView {
                Text(speechService.transcribedText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .frame(maxHeight: 120)
        }
        .padding(.horizontal, 24)
        .transition(.scale.combined(with: .opacity))
    }
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Create interview button (only show if we have transcription)
            if !speechService.transcribedText.isEmpty {
                Button(action: createInterview) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Create Interview")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ColorTheme.primaryAccent)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(viewModel.isLoading)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Cancel button
            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            // Loading animation
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Creating Your Interview...")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Text("AI is generating personalized questions based on your topic")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Computed Properties
    
    private var microphoneColor: Color {
        if !speechService.isAuthorized {
            return .gray
        } else if isListening {
            return .green
        } else {
            return .white
        }
    }
    
    private var statusText: String {
        if !speechService.isAuthorized {
            return "Microphone access required"
        } else if speechService.isTranscribing {
            return "Listening..."
        } else if isListening {
            return "Speak now"
        } else if !speechService.transcribedText.isEmpty {
            return "Tap mic to record again"
        } else {
            return "Tap to start speaking"
        }
    }
    
    // MARK: - Actions
    
    private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        guard speechService.isAuthorized else {
            showingPermissionAlert = true
            return
        }
        
        isListening = true
        hasStartedListening = true
        speechService.startLiveTranscription()
    }
    
    private func stopListening() {
        isListening = false
        speechService.stopTranscription()
    }
    
    private func createInterview() {
        let transcription = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcription.isEmpty else { return }
        
        viewModel.topic = transcription
        
        Task {
            await viewModel.createProject()
        }
    }
    
    private func handleTranscriptionUpdate(_ newText: String) {
        // If transcription is complete and we have text, stop listening
        if !newText.isEmpty && hasStartedListening && !speechService.isTranscribing {
            isListening = false
        }
    }
    
    private func requestPermissions() {
        // Permissions are automatically requested by SpeechToTextService
    }
    
    private func cleanupAudio() {
        speechService.stopTranscription()
        isListening = false
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    SpeechFirstCreateView { project in
        print("Project created: \(project.title)")
    }
}