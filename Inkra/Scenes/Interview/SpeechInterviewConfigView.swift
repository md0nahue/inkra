import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct SpeechInterviewConfigView: View {
    // Custom topic passed in from the InterviewModeSelectionView
    let customTopic: String?
    let onProjectCreated: ((Project) -> Void)?
    
    @State private var isSpeechEnabled = true // Always true in this new flow
    @State private var selectedVoiceId = "Matthew"
    @State private var speechRate = 1.0
    @State private var showVoiceSelection = false
    @State private var isCreatingProject = false
    @State private var createdProject: Project?
    @State private var showLoadingScreen = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    
                    speechToggleSection
                    
                    if isSpeechEnabled {
                        voiceConfigSection
                        
                        saveButton
                        
                        benefitsSection
                    } else {
                        textOnlyBenefitsSection
                        
                        saveButton
                    }
                }
                .padding()
            }
            .navigationTitle(isSpeechEnabled ? "Speech Interview" : "Focus Interview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showVoiceSelection) {
                VoiceSelectionView(initialVoiceId: selectedVoiceId, initialSpeechRate: speechRate) { voiceId, rate in
                    selectedVoiceId = voiceId
                    speechRate = rate
                }
            }
            }
            .disabled(isCreatingProject || showLoadingScreen)
            
            // Full-screen loading overlay
            if showLoadingScreen {
                InterviewCreationLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                    .zIndex(1000) // Ensure it's on top
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: isSpeechEnabled ? "waveform.and.mic" : "text.alignleft")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ColorTheme.primaryAccent, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(isSpeechEnabled ? "AI-Powered Speech Interview" : "Focus Mode Interview")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(isSpeechEnabled ? 
                 "Transform your interview into a hands-free, conversational experience with natural AI voices." :
                 "Perfect for reading when you don't have the chance to listen or need your hands available. Dive deep into thoughtful, distraction-free reflection."
            )
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }
    
    private var speechToggleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $isSpeechEnabled) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enable Speech Interview")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(isSpeechEnabled ? 
                         "Questions will be read aloud with automatic progression based on your speech patterns." :
                         "Questions will be displayed as text for you to read at your own pace. Perfect for quiet environments or when you prefer visual focus."
                    )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: ColorTheme.primaryAccent))
        }
        .padding()
        .background(ColorTheme.cardBackground)
        .cornerRadius(12)
    }
    
    private var voiceConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: {
                showVoiceSelection = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice: \(selectedVoiceId)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ColorTheme.primaryText)
                        
                        Text(String(format: "Speed: %.1fx", speechRate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(ColorTheme.cardBackground)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Perfect For")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(
                    icon: "car.fill",
                    title: "Hands-Free Recording",
                    description: "Perfect for recording while driving or walking"
                )
                
                BenefitRow(
                    icon: "brain.head.profile",
                    title: "Natural Flow",
                    description: "Automatic progression keeps your thoughts flowing"
                )
                
                BenefitRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Great for users with reading difficulties"
                )
                
                BenefitRow(
                    icon: "speaker.wave.3.fill",
                    title: "Immersive Experience",
                    description: "Feel like you're having a real conversation"
                )
            }
        }
    }
    
    private var textOnlyBenefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Why Choose Focus Mode?")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(
                    icon: "eye.fill",
                    title: "Deep Reading Experience",
                    description: "Read questions at your own pace for thoughtful responses"
                )
                
                BenefitRow(
                    icon: "hand.raised.fill",
                    title: "Hands Available",
                    description: "Perfect when you need to use your hands for other tasks"
                )
                
                BenefitRow(
                    icon: "location.slash.fill",
                    title: "Silent Environments",
                    description: "Ideal for libraries, meetings, or quiet spaces"
                )
                
                BenefitRow(
                    icon: "brain.fill",
                    title: "Focused Thinking",
                    description: "Visual reading promotes deeper, more deliberate reflection"
                )
                
                BenefitRow(
                    icon: "battery.100",
                    title: "Lower Battery Usage",
                    description: "Text-only mode conserves device battery and data"
                )
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            Task {
                await createProjectAndNavigate()
            }
        }) {
            HStack {
                if isCreatingProject {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle")
                }
                Text(isCreatingProject ? "Creating Interview..." : "Start Interview")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(ColorTheme.primaryAccent)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(isCreatingProject)
    }
    
    private func createProjectAndNavigate() async {
        isCreatingProject = true
        showLoadingScreen = true
        
        do {
            let syncService = SyncService.shared
            let topic = customTopic ?? "Untitled"
            
            // DEBUG LOGGING
            print("\n🔍 CUSTOM INTERVIEW DEBUG - Speech Config View")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📝 Custom Topic: \(topic)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            // Create the project directly with speech settings
            let project = try await syncService.createProject(
                title: topic,
                isSpeechInterview: isSpeechEnabled,
                presetUuid: nil,
                voiceId: isSpeechEnabled ? selectedVoiceId : nil,
                speechRate: isSpeechEnabled ? Int(speechRate * 100) : nil
            )
            
            print("\n✅ PROJECT CREATED SUCCESSFULLY")
            print("   - Project ID: \(project.id)")
            print("   - Project Title: \(project.title)")
            print("   - Custom Project (No Preset)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

            // Save speech configuration if speech is enabled
            if isSpeechEnabled {
                saveUserSpeechPreferences(for: project.id)

                // Trigger Polly audio generation in background - don't wait for it
                Task {
                    let pollyService = PollyAudioGenerationService.shared
                    await pollyService.triggerInitialGeneration(
                        projectId: project.id,
                        voiceId: selectedVoiceId,
                        speechRate: Int(speechRate * 100)
                    )
                }
            }

            await MainActor.run {
                // Stop the loading state first
                isCreatingProject = false
                showLoadingScreen = false
                
                // --- THIS IS THE CRITICAL HAND-OFF ---
                // Call the closure to pass the project back - parent will handle dismissal and navigation
                onProjectCreated?(project)
            }
        } catch {
            await MainActor.run {
                print("Failed to create project: \(error)")
                showLoadingScreen = false
                isCreatingProject = false
            }
        }
    }
    
    private func saveUserSpeechPreferences(for projectId: Int) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "project_\(projectId)_speech_enabled")
        defaults.set(selectedVoiceId, forKey: "project_\(projectId)_voice_id")
        defaults.set(speechRate, forKey: "project_\(projectId)_speech_rate")
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(ColorTheme.primaryAccent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SpeechInterviewConfigView(
        customTopic: "Sample Topic",
        onProjectCreated: nil
    )
}