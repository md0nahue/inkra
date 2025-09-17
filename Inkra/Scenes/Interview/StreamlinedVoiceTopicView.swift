import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct StreamlinedVoiceTopicView: View {
    let selectedVoiceId: String
    let speechRate: Double
    
    // Navigation state enum to prevent conflicts
    enum NavigationDestination {
        case none
        case voiceInput
        case textInput
        case interview(Project)
    }
    
    @State private var navigationDestination: NavigationDestination = .none
    @State private var isNavigationActive = false
    @State private var interviewTopic: String?
    @State private var isCreatingProject = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var lastCreationAttempt: Date?
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("What's Your Story?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Tap the button below to record your interview topic")
                    .font(.body)
                    .foregroundColor(ColorTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                // Primary Voice Input Option (Big Button)
                Button(action: {
                    navigationDestination = .voiceInput
                    isNavigationActive = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                        
                        Text("Tap to Record Your Topic")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 24)
                
                // Alternative: Type Instead (Subtle Link)
                Button(action: {
                    navigationDestination = .textInput
                    isNavigationActive = true
                }) {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("Prefer to type instead?")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(ColorTheme.primaryAccent)
                    .font(.subheadline)
                }
                .padding(.top, 8)
            }
            
            Spacer()
            Spacer()
        }
        .navigationTitle("Spoken Interview")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.primaryBackground)
        .background(
            NavigationLink(
                destination: destinationView(),
                isActive: $isNavigationActive
            ) {
                EmptyView()
            }
        )
        .overlay(
            Group {
                if isCreatingProject {
                    InterviewCreationLoadingView(
                        onError: {
                            // Handle loading error gracefully
                            isCreatingProject = false
                            showError = true
                            errorMessage = "There was an issue creating your interview. Please try again."
                        },
                        onDismiss: {
                            // Dismiss loading screen and return to topic selection
                            isCreatingProject = false
                        }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isCreatingProject)
        )
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private func destinationView() -> some View {
        switch navigationDestination {
        case .none:
            EmptyView()
        case .voiceInput:
            VoiceInputView { topic in
                print("🎯 DEBUG StreamlinedVoiceTopicView: VoiceInputView callback triggered with topic: '\(topic)'")
                interviewTopic = topic
                // Reset navigation state first
                isNavigationActive = false
                navigationDestination = .none
                // Small delay to ensure navigation dismissal before starting creation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    createInterview(topic: topic)
                }
            }
        case .textInput:
            TypeYourTopicView { topic in
                print("🎯 DEBUG StreamlinedVoiceTopicView: TypeYourTopicView callback triggered with topic: '\(topic)'")
                interviewTopic = topic
                // Reset navigation state first
                isNavigationActive = false
                navigationDestination = .none
                // Small delay to ensure navigation dismissal before starting creation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    createInterview(topic: topic)
                }
            }
        case .interview(let project):
            InterviewSessionView(project: project)
        }
    }
    
    private func createInterview(topic: String) {
        print("🎯 DEBUG StreamlinedVoiceTopicView: createInterview called with topic: '\(topic)'")
        
        // Prevent duplicate creation attempts within 5 seconds
        let now = Date()
        if let lastAttempt = lastCreationAttempt,
           now.timeIntervalSince(lastAttempt) < 5.0 {
            print("🚨 DEBUG StreamlinedVoiceTopicView: Duplicate creation attempt blocked")
            return
        }
        
        // Also prevent if already creating
        guard !isCreatingProject else {
            print("🚨 DEBUG StreamlinedVoiceTopicView: Creation already in progress")
            return
        }
        
        lastCreationAttempt = now
        
        Task {
            do {
                // Show loading screen immediately
                await MainActor.run {
                    isCreatingProject = true
                }
                
                let syncService = SyncService.shared
                
                // Add timeout for project creation
                let projectCreationTimeout: UInt64 = 30_000_000_000 // 30 seconds
                
                let newProject: Project
                do {
                    newProject = try await withThrowingTaskGroup(of: Project.self) { group in
                        group.addTask {
                            return try await syncService.createProject(
                                title: topic,
                                isSpeechInterview: true,
                                presetId: nil,
                                voiceId: selectedVoiceId,
                                speechRate: Int(speechRate * 100)
                            )
                        }
                        
                        group.addTask {
                            try await Task.sleep(nanoseconds: projectCreationTimeout)
                            throw NSError(domain: "StreamlinedVoiceTopicView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Project creation timed out after 30 seconds"])
                        }
                        
                        defer { group.cancelAll() }
                        return try await group.next()!
                    }
                } catch {
                    print("🎯 DEBUG StreamlinedVoiceTopicView: Project creation failed or timed out: \(error)")
                    throw error
                }
                
                print("🎯 DEBUG StreamlinedVoiceTopicView: Project created successfully with ID: \(newProject.id)")
                
                // For speech interviews, poll until ready
                var projectReady = false
                var pollCount = 0
                
                let projectService = ProjectService()
                
                while !projectReady {
                    pollCount += 1
                    
                    // Wait before checking - polling every 1 second
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Check if project has questions ready
                    do {
                        let questionsResponse = try await projectService.getAvailableQuestions(projectId: newProject.id)
                        if !questionsResponse.questions.isEmpty {
                            if let firstQuestion = questionsResponse.questions.first {
                                // Check if first question has audio ready (for speech interviews)
                                if firstQuestion.pollyAudioUrl != nil {
                                    projectReady = true
                                }
                            }
                        }
                    } catch {
                        // Questions might not be ready yet
                        print("🎯 DEBUG StreamlinedVoiceTopicView: Error fetching questions (attempt \(pollCount)): \(error)")
                    }
                }
                
                // Small delay to ensure loading screen has time to be visible before transition
                if projectReady {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                
                await MainActor.run {
                    if projectReady {
                        // Hide loading screen first
                        isCreatingProject = false
                        
                        // Set navigation destination to the interview with the created project
                        navigationDestination = .interview(newProject)
                        
                        // Small delay to ensure UI updates before navigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isNavigationActive = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isCreatingProject = false
                    isNavigationActive = false
                    navigationDestination = .none
                    errorMessage = "Failed to create interview: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    StreamlinedVoiceTopicView(selectedVoiceId: "Matthew", speechRate: 1.0)
}