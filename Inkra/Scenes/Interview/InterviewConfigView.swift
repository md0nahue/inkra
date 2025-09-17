import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct InterviewConfigView: View {
    let customTopic: String
    @State private var selectedMode: InterviewMode = .reading
    @State private var isSpeechEnabled = false
    @State private var selectedVoiceId = "Matthew"
    @State private var speechRate = 100
    @State private var showVoiceSelection = false
    @State private var isCreatingProject = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var navigateToInterview = false
    @State private var createdProject: Project?
    @Environment(\.dismiss) private var dismiss
    
    enum InterviewMode {
        case spoken
        case reading
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        modeSelectionSection
                        
                        if selectedMode == .spoken {
                            voiceConfigSection
                        }
                        
                        benefitsSection
                        
                        Spacer(minLength: 40)
                        
                        continueButton
                    }
                    .padding()
                }
                .navigationTitle("Choose Interview Format")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showVoiceSelection) {
                    VoiceSelectionView(initialVoiceId: selectedVoiceId, initialSpeechRate: Double(speechRate) / 100.0) { voiceId, rate in
                        selectedVoiceId = voiceId
                        speechRate = Int(rate * 100)
                    }
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage)
                }
                .navigationDestination(isPresented: $navigateToInterview) {
                    if let project = createdProject {
                        InterviewSessionView(project: project)
                    }
                }
                .disabled(isCreatingProject)
            }
        } else {
            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        modeSelectionSection
                        
                        if selectedMode == .spoken {
                            voiceConfigSection
                        }
                        
                        benefitsSection
                        
                        Spacer(minLength: 40)
                        
                        continueButton
                    }
                    .padding()
                }
                .navigationTitle("Choose Interview Format")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showVoiceSelection) {
                    VoiceSelectionView(initialVoiceId: selectedVoiceId, initialSpeechRate: Double(speechRate) / 100.0) { voiceId, rate in
                        selectedVoiceId = voiceId
                        speechRate = Int(rate * 100)
                    }
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage)
                }
                .disabled(isCreatingProject)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Custom Interview")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(customTopic)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }
    
    private var modeSelectionSection: some View {
        VStack(spacing: 16) {
            Text("How would you like to experience your interview?")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                modeOptionCard(
                    mode: .reading,
                    icon: "text.book.closed",
                    title: "Read & Record",
                    description: "Read questions on screen and record at your own pace",
                    features: ["See all questions at once", "Skip or revisit questions", "Perfect for visual learners"]
                )
                
                modeOptionCard(
                    mode: .spoken,
                    icon: "waveform.and.mic",
                    title: "Spoken Interview",
                    description: "Questions read aloud with hands-free recording",
                    features: ["AI voice narration", "Automatic progression", "Great for driving or walking"]
                )
            }
        }
    }
    
    private func modeOptionCard(mode: InterviewMode, icon: String, title: String, description: String, features: [String]) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedMode = mode
                isSpeechEnabled = (mode == .spoken)
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(selectedMode == mode ? ColorTheme.primaryAccent : Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(selectedMode == mode ? .white : .gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(ColorTheme.primaryText)
                        
                        Text(description)
                            .font(.caption)
                            .foregroundColor(ColorTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    if selectedMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(ColorTheme.primaryAccent)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(selectedMode == mode ? ColorTheme.primaryAccent : .gray)
                            
                            Text(feature)
                                .font(.caption)
                                .foregroundColor(ColorTheme.tertiaryText)
                        }
                    }
                }
                .padding(.leading, 66)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedMode == mode ? ColorTheme.primaryAccent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var voiceConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: {
                showVoiceSelection = true
            }) {
                HStack {
                    Image(systemName: "speaker.wave.3")
                        .font(.title3)
                        .foregroundColor(ColorTheme.primaryAccent)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice: \(selectedVoiceId)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ColorTheme.primaryText)
                        
                        Text("Speed: \(speechRate)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Change")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ColorTheme.primaryAccent)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(ColorTheme.cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tips for Success")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                TipRow(
                    icon: "lightbulb",
                    text: selectedMode == .spoken 
                        ? "Find a quiet space where you can speak freely"
                        : "Take your time to read and reflect on each question"
                )
                
                TipRow(
                    icon: "clock",
                    text: selectedMode == .spoken
                        ? "The interview will auto-advance after detecting silence"
                        : "You can skip questions and return to them later"
                )
                
                TipRow(
                    icon: "sparkles",
                    text: "Your responses will be transcribed and organized automatically"
                )
            }
            .padding()
            .background(ColorTheme.cardBackground.opacity(0.5))
            .cornerRadius(12)
        }
    }
    
    private var continueButton: some View {
        Button(action: {
            Task {
                await createProjectAndNavigate()
            }
        }) {
            HStack {
                if isCreatingProject {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.right.circle")
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
        
        do {
            let syncService = SyncService.shared
            
            let topic = customTopic
            
            // Create project through SyncService with all settings
            let finalProject = try await syncService.createProject(
                title: topic,
                isSpeechInterview: isSpeechEnabled,
                presetId: nil,
                voiceId: isSpeechEnabled ? selectedVoiceId : nil,
                speechRate: isSpeechEnabled ? Int(speechRate * 100) : nil
            )
            
            // Save speech configuration if enabled
            if isSpeechEnabled {
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: "project_\(finalProject.id)_speech_enabled")
                defaults.set(selectedVoiceId, forKey: "project_\(finalProject.id)_voice_id")
                defaults.set(speechRate, forKey: "project_\(finalProject.id)_speech_rate")
            }
            
            await MainActor.run {
                createdProject = finalProject
                navigateToInterview = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create interview: \(error.localizedDescription)"
                showError = true
                isCreatingProject = false
            }
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(ColorTheme.primaryAccent)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(ColorTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

#Preview {
    InterviewConfigView(
        customTopic: "Tell me about your life story"
    )
}