import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct InterviewModeSelectionView: View {
    // Custom topic passed in from the previous screen
    let customTopic: String?

    // Navigation states
    @State private var navigateToConfig = false
    @State private var navigateToProjectDetail: Project?
    @State private var navigateToInterview: Project?

    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("How would you like to conduct your interview?")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Option 1: Reading Mode
            Button(action: { createTask(isSpeech: false) }) {
                ModeCard(
                    icon: "text.book.closed.fill",
                    title: "Reading Mode",
                    description: "Start your interview right away - read questions and respond at your own pace.",
                    color: .blue
                )
            }

            // Option 2: Spoken AI Interview
            Button(action: { navigateToConfig = true }) {
                ModeCard(
                    icon: "waveform.and.mic",
                    title: "Spoken AI Interview",
                    description: "An AI voice reads questions to you. The interview advances automatically when you finish speaking.",
                    color: .purple
                )
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Interview Mode")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isCreating)
        .overlay(
            isCreating ? 
            InterviewCreationLoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            : nil
        )
        .background(
            Group {
                NavigationLink(
                    destination: SpeechInterviewConfigView(
                        customTopic: customTopic,
                        onProjectCreated: { project in
                            navigateToProjectDetail = project
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                navigateToConfig = false
                            }
                        }
                    ),
                    isActive: $navigateToConfig
                ) { EmptyView() }
                .hidden()
                
                if let project = navigateToProjectDetail {
                    NavigationLink(
                        destination: ProjectDetailView(project: project),
                        isActive: .constant(true)
                    ) { EmptyView() }
                    .hidden()
                }
                
                if let project = navigateToInterview {
                    NavigationLink(
                        destination: InterviewSessionView(project: project),
                        isActive: .constant(true)
                    ) { EmptyView() }
                    .hidden()
                }
            }
        )
        .background(
             // A subtle background to make it feel distinct
            LinearGradient(colors: [.black, .gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
               .ignoresSafeArea()
        )
    }

    private func createTask(isSpeech: Bool) {
        Task {
            isCreating = true
            do {
                let syncService = SyncService.shared
                let topic = customTopic ?? "Untitled"
                let newProject = try await syncService.createProject(title: topic, isSpeechInterview: isSpeech, presetId: nil, voiceId: nil, speechRate: nil)
                
                if isSpeech {
                    // For speech interviews, go to project detail (existing behavior)
                    navigateToProjectDetail = newProject
                } else {
                    // For reading mode, go directly to interview session
                    navigateToInterview = newProject
                }
            } catch {
                // Handle error
                print("❌ Failed to create project: \(error)")
            }
            isCreating = false
        }
    }
}

// A reusable card for the selection buttons
struct ModeCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
                .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).fontWeight(.bold)
                Text(description).font(.subheadline).foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}