import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct ReadingInterviewTopicView: View {
    let interviewLength: InterviewLength
    @State private var navigateToVoiceInput = false
    @State private var navigateToTextInput = false
    @State private var interviewTopic: String?
    @State private var isCreatingProject = false
    @State private var createdProject: Project?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "text.book.closed.fill")
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
                
                Text("Tell us what you'd like to talk about in your reading interview")
                    .font(.body)
                    .foregroundColor(ColorTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                // Voice Input Option
                Button(action: {
                    navigateToVoiceInput = true
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
                    navigateToTextInput = true
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
        .navigationTitle("Reading Interview")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.primaryBackground)
        .modifier(NavigationDestinationModifier(
            isPresented: $navigateToVoiceInput,
            destination: {
                VoiceInputView { topic in
                    interviewTopic = topic
                    navigateToVoiceInput = false
                    createInterview(topic: topic)
                }
            }
        ))
        .modifier(NavigationDestinationModifier(
            isPresented: $navigateToTextInput,
            destination: {
                TypeYourTopicView { topic in
                    interviewTopic = topic
                    navigateToTextInput = false
                    createInterview(topic: topic)
                }
            }
        ))
        .modifier(NavigationDestinationProjectModifier(
            item: $createdProject,
            destination: { project in
                InterviewSessionView(project: project)
            }
        ))
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
    
    private func createInterview(topic: String) {
        isCreatingProject = true
        
        Task {
            do {
                let syncService = SyncService.shared
                let newProject = try await syncService.createProject(
                    title: topic,
                    isSpeechInterview: false,
                    presetId: nil,
                    voiceId: nil,
                    speechRate: nil,
                    interviewLength: interviewLength.apiValue,
                    questionCount: interviewLength.questionCount
                )
                
                await MainActor.run {
                    isCreatingProject = false
                    createdProject = newProject
                }
            } catch {
                await MainActor.run {
                    isCreatingProject = false
                    errorMessage = "Failed to create interview: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// Navigation modifiers moved to NavigationModifiers.swift

#Preview {
    ReadingInterviewTopicView(interviewLength: .tenMinutes)
}