import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct VoiceInterviewTopicView: View {
    let selectedVoiceId: String
    let speechRate: Double
    let interviewLength: InterviewLength
    
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
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("What's Your Story?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Tell us what you'd like to talk about in your interview")
                    .font(.body)
                    .foregroundColor(ColorTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                // Voice Input Option
                Button(action: {
                    navigationDestination = .voiceInput
                    isNavigationActive = true
                }) {
                    HStack(spacing: 20) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                            .frame(width: 60)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Record Your Topic")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(ColorTheme.primaryText)
                            
                            Text("Speak about what you want to discuss")
                                .font(.subheadline)
                                .foregroundColor(ColorTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18))
                            .foregroundColor(ColorTheme.tertiaryText)
                    }
                    .padding(20)
                    .background(ColorTheme.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ColorTheme.primaryAccent.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Text Input Option
                Button(action: {
                    navigationDestination = .textInput
                    isNavigationActive = true
                }) {
                    HStack(spacing: 20) {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                            .frame(width: 60)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Type Your Topic")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(ColorTheme.primaryText)
                            
                            Text("Write about what you want to discuss")
                                .font(.subheadline)
                                .foregroundColor(ColorTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18))
                            .foregroundColor(ColorTheme.tertiaryText)
                    }
                    .padding(20)
                    .background(ColorTheme.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ColorTheme.primaryAccent.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            
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
                print("🎯 DEBUG VoiceInterviewTopicView: VoiceInputView callback triggered with topic: '\(topic)'")
                interviewTopic = topic
                print("🎯 DEBUG VoiceInterviewTopicView: Set interviewTopic to: '\(topic)'")
                // Reset navigation state first
                isNavigationActive = false
                navigationDestination = .none
                // Small delay to ensure navigation dismissal before starting creation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🎯 DEBUG VoiceInterviewTopicView: About to call createInterview")
                    createInterview(topic: topic)
                }
            }
        case .textInput:
            TypeYourTopicView { topic in
                print("🎯 DEBUG VoiceInterviewTopicView: TypeYourTopicView callback triggered with topic: '\(topic)'")
                interviewTopic = topic
                print("🎯 DEBUG VoiceInterviewTopicView: Set interviewTopic to: '\(topic)'")
                // Reset navigation state first
                isNavigationActive = false
                navigationDestination = .none
                // Small delay to ensure navigation dismissal before starting creation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🎯 DEBUG VoiceInterviewTopicView: About to call createInterview")
                    createInterview(topic: topic)
                }
            }
        case .interview(let project):
            InterviewSessionView(project: project)
        }
    }
    
    private func createInterview(topic: String) {
        print("🎯 DEBUG VoiceInterviewTopicView: createInterview called with topic: '\(topic)'")
        
        // Prevent duplicate creation attempts within 5 seconds
        let now = Date()
        if let lastAttempt = lastCreationAttempt,
           now.timeIntervalSince(lastAttempt) < 5.0 {
            print("🚨 DEBUG VoiceInterviewTopicView: Duplicate creation attempt blocked - last attempt was \(now.timeIntervalSince(lastAttempt)) seconds ago")
            return
        }
        
        // Also prevent if already creating
        guard !isCreatingProject else {
            print("🚨 DEBUG VoiceInterviewTopicView: Creation already in progress - blocking duplicate attempt")
            return
        }
        
        lastCreationAttempt = now
        
        Task {
            do {
                print("🎯 DEBUG VoiceInterviewTopicView: Starting createInterview task")
                // Show loading screen immediately
                await MainActor.run {
                    print("🎯 DEBUG VoiceInterviewTopicView: Setting isCreatingProject=true")
                    isCreatingProject = true
                    print("🎯 DEBUG VoiceInterviewTopicView: isCreatingProject set, navigation is ready")
                }
                
                print("🎯 DEBUG VoiceInterviewTopicView: Creating project via SyncService")
                let syncService = SyncService.shared
                
                // Add timeout for project creation to avoid hanging
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
                                speechRate: Int(speechRate * 100),
                                interviewLength: interviewLength.apiValue,
                                questionCount: interviewLength.questionCount
                            )
                        }
                        
                        group.addTask {
                            try await Task.sleep(nanoseconds: projectCreationTimeout)
                            throw NSError(domain: "VoiceInterviewTopicView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Project creation timed out after 30 seconds"])
                        }
                        
                        defer { group.cancelAll() }
                        return try await group.next()!
                    }
                } catch {
                    print("🎯 DEBUG VoiceInterviewTopicView: Project creation failed or timed out: \(error)")
                    throw error
                }
                
                print("🎯 DEBUG VoiceInterviewTopicView: Project created successfully with ID: \(newProject.id)")
                
                // For speech interviews, we need to wait for the interview to be fully scaffolded
                // Poll the project status until it's ready - no timeout, keep trying until success
                var projectReady = false
                var pollCount = 0
                
                print("🎯 DEBUG VoiceInterviewTopicView: Starting persistent polling for interview scaffolding for project ID: \(newProject.id)")
                // Create a project service instance to check questions
                let projectService = ProjectService()
                
                while !projectReady {
                    pollCount += 1
                    print("🎯 DEBUG VoiceInterviewTopicView: Polling attempt \(pollCount) for project ID: \(newProject.id)")
                    
                    // Wait before checking - polling every 1 second
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Check if project has questions ready
                    do {
                        let questionsResponse = try await projectService.getAvailableQuestions(projectId: newProject.id)
                        print("🎯 DEBUG VoiceInterviewTopicView: Questions received for project \(newProject.id): \(questionsResponse.questions.count) questions")
                        if !questionsResponse.questions.isEmpty {
                            if let firstQuestion = questionsResponse.questions.first {
                                print("🎯 DEBUG VoiceInterviewTopicView: First question audio URL: \(firstQuestion.pollyAudioUrl ?? "nil")")
                                // Check if first question has audio ready (for speech interviews)
                                if firstQuestion.pollyAudioUrl != nil {
                                    print("🎯 DEBUG VoiceInterviewTopicView: Project \(newProject.id) is ready! Audio URL exists for first question")
                                    projectReady = true
                                } else {
                                    print("🎯 DEBUG VoiceInterviewTopicView: Questions exist for project \(newProject.id) but no audio URL yet")
                                }
                            }
                        } else {
                            print("🎯 DEBUG VoiceInterviewTopicView: No questions available yet for project \(newProject.id)")
                        }
                    } catch {
                        // Questions might not be ready yet
                        print("🎯 DEBUG VoiceInterviewTopicView: Error fetching questions for project \(newProject.id) (attempt \(pollCount)): \(error)")
                    }
                }
                
                // Small delay to ensure loading screen has time to be visible before transition
                if projectReady {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds - increased for stability
                }
                
                await MainActor.run {
                    print("🎯 DEBUG VoiceInterviewTopicView: Back on MainActor, preparing for transition")
                    if projectReady {
                        print("🎯 DEBUG VoiceInterviewTopicView: Project is ready! Setting navigation destination to interview")
                        // Hide loading screen first
                        isCreatingProject = false
                        
                        // Set navigation destination to the interview with the created project
                        navigationDestination = .interview(newProject)
                        
                        // Small delay to ensure UI updates before navigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("🎯 DEBUG VoiceInterviewTopicView: Triggering navigation to InterviewSessionView")
                            isNavigationActive = true
                            print("🎯 DEBUG VoiceInterviewTopicView: Navigation activated - should navigate to InterviewSessionView now")
                        }
                    }
                }
            } catch {
                print("🎯 DEBUG VoiceInterviewTopicView: Error in createInterview: \(error)")
                await MainActor.run {
                    isCreatingProject = false
                    isNavigationActive = false
                    navigationDestination = .none
                    errorMessage = "Failed to create interview: \(error.localizedDescription)"
                    showError = true
                    print("🎯 DEBUG VoiceInterviewTopicView: Error state set, showing error to user")
                }
            }
        }
    }
}

#Preview {
    VoiceInterviewTopicView(selectedVoiceId: "Matthew", speechRate: 1.0, interviewLength: .tenMinutes)
}