import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct ProjectDetailView: View {
    let project: Project
    let navigationSource: ProjectNavigationSource
    @StateObject private var viewModel: ProjectDetailViewModel
    @State private var isGeneratingChapters = false
    @State private var navigateToInterview = false
    @State private var showingDeleteAlert = false
    @State private var showingSpeechConfig = false
    @State private var showingAudiogramView = false
    @State private var showingPodcastExportView = false
    @State private var showingExportOptions = false
    @State private var navigateToHome = false
    @State private var navigateToMyInterviews = false
    @State private var navigateToTranscript = false
    @Environment(\.dismiss) private var dismiss
    
    init(project: Project, navigationSource: ProjectNavigationSource = .home) {
        self.project = project
        self.navigationSource = navigationSource
        self._viewModel = StateObject(wrappedValue: ProjectDetailViewModel(project: project))
    }
    
    var body: some View {
        navigationView
    }
    
    private var navigationView: some View {
        mainContent
            .modifier(NavigationModifier())
            .modifier(ToolbarModifier(
                navigationSource: navigationSource,
                navigateToHome: $navigateToHome,
                navigateToMyInterviews: $navigateToMyInterviews,
                showingDeleteAlert: $showingDeleteAlert
            ))
            .modifier(AlertsModifier(
                showingDeleteAlert: $showingDeleteAlert,
                showError: $viewModel.showError,
                errorMessage: viewModel.errorMessage,
                viewModel: viewModel
            ))
            .modifier(NavigationDestinationsModifier(
                navigateToInterview: $navigateToInterview,
                navigateToHome: $navigateToHome,
                navigateToMyInterviews: $navigateToMyInterviews,
                navigateToTranscript: $navigateToTranscript,
                currentProject: viewModel.currentProject
            ))
            .modifier(SheetsModifier(
                showingSpeechConfig: $showingSpeechConfig,
                showingAudiogramView: $showingAudiogramView,
                showingPodcastExportView: $showingPodcastExportView,
                showingExportOptions: $showingExportOptions,
                currentProject: viewModel.currentProject
            ))
            .modifier(ViewModelObserversModifier(
                viewModel: viewModel,
                dismiss: dismiss,
                navigateToHome: $navigateToHome,
                navigateToMyInterviews: $navigateToMyInterviews
            ))
    }
    
    private var mainContent: some View {
        Group {
            if shouldShowGeneratingView {
                generatingView
                    .background(Color(.systemBackground))
            } else if viewModel.isLoading && viewModel.currentProject.outline == nil {
                loadingView
                    .background(Color(.systemBackground))
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with preset branding
                        projectHeaderSection
                        
                        
                        if let outline = viewModel.currentProject.outline {
                            outlineSection(outline)
                        }
                        
                        actionSection
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .task {
            await viewModel.loadProjectDetails()
        }
    }
    
    private var generatingView: some View {
        // Use the same full-page image carousel loading view with error handling
        VoiceInterviewCreationWaitingView(
            onError: {
                // Handle error - could trigger a refresh or show different state
                Task {
                    await viewModel.refreshProject()
                }
            },
            onDismiss: {
                // Go back to previous view
                dismiss()
            }
        )
    }

    private var loadingView: some View {
        // Use the same full-page image carousel loading view with error handling  
        VoiceInterviewCreationWaitingView(
            onError: {
                // Handle error - could trigger a refresh or show different state
                Task {
                    await viewModel.refreshProject()
                }
            },
            onDismiss: {
                // Go back to previous view
                dismiss()
            }
        )
    }
    
    
    
    // Removed old button title/subtitle methods - replaced with toggle UI
    
    private var canViewTranscript: Bool {
        // Allow viewing transcript if there are any responses (answers) to questions
        return viewModel.hasAnyResponses
    }
    
    private var transcriptSubtitle: String {
        if canViewTranscript {
            return "View all questions and answers"
        } else {
            return "Transcript will be available after answering questions"
        }
    }
    
    private var transcriptButtonColor: Color {
        canViewTranscript ? .green : .gray
    }
    
    private var shouldShowGeneratingView: Bool {
        guard viewModel.currentProject.outline?.status == .generating else {
            return false
        }
        
        // Never show generating view if the project has completed an interview
        // This prevents getting stuck on the "Generating your Outline" screen
        // after interview completion
        let status = viewModel.currentProject.status
        if status == .completed || status == .transcribing {
            return false
        }
        
        // Also don't show if there are existing recordings (indicates interview was started)
        // This helps avoid the generating screen when returning from interview
        if viewModel.currentProject.outline?.chapters.contains(where: { chapter in
            chapter.sections.contains(where: { section in
                section.questions.contains(where: { question in
                    // Check if this question has any associated recordings
                    // (This would need to be implemented in the model if not already available)
                    return false // For now, just rely on status check
                })
            })
        }) == true {
            return false
        }
        
        return true
    }
    
    private var canViewQA: Bool {
        // Q&A can be viewed if there are questions (outline exists)
        return viewModel.currentProject.outline != nil
    }
    
    private var qaSubtitle: String {
        if canViewQA {
            let totalQuestions = viewModel.currentProject.totalQuestionCount
            if totalQuestions > 0 {
                return "See all \(totalQuestions) interview questions and responses"
            } else {
                return "See all interview questions and responses"
            }
        } else {
            return "Questions will be available after outline generation"
        }
    }
    
    private var qaButtonColor: Color {
        canViewQA ? .blue : .gray
    }
    
    private func outlineSection(_ outline: Outline) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Project Outline")
                    .font(.headline)
                Spacer()
                NavigationLink("Edit") {
                    OutlineEditView(project: viewModel.currentProject)
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            // Estimated interview time section
            if outline.status == .ready && viewModel.currentProject.totalQuestionCount > 0 {
                estimatedTimeCard
            }
            
            if outline.status == .generating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating outline...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                outlineList(outline.chapters)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func outlineList(_ chapters: [Chapter]) -> some View {
        VStack(spacing: 8) {
            ForEach(chapters.prefix(3)) { chapter in
                chapterRow(chapter)
            }
            
            if chapters.count > 3 {
                Text("+ \(chapters.count - 3) more chapters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func chapterRow(_ chapter: Chapter) -> some View {
        HStack {
            Image(systemName: chapter.omitted ? "circle" : "checkmark.circle.fill")
                .foregroundColor(chapter.omitted ? .secondary : .accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(chapter.omitted)
                
                Text("\(chapter.sections.count) sections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var estimatedTimeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated Interview Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(viewModel.currentProject.formattedEstimatedTime)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.currentProject.totalQuestionCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("questions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Based on 30 seconds per question. Generate more chapters to extend your interview time.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            recordingButton
            
            if viewModel.currentProject.outline?.status == .ready {
                generateChaptersButton
                interviewModeToggle
            }
            
            if viewModel.currentProject.outline?.status != .generating {
                postInterviewActions
            }
        }
    }
    
    private var recordingButton: some View {
        Button(action: {
            navigateToInterview = true
            Task {
                await viewModel.startRecording()
            }
        }) {
            actionButton(
                title: "Start Recording",
                subtitle: "Begin your interview session",
                icon: "record.circle",
                color: .red,
                isLoading: viewModel.isStartingRecording
            )
        }
        .disabled(viewModel.isStartingRecording)
    }
    
    private var generateChaptersButton: some View {
        Button {
            guard !isGeneratingChapters && !viewModel.isLoading else { return }
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            isGeneratingChapters = true
            
            Task { @MainActor in
                await viewModel.addMoreChapters()
                isGeneratingChapters = false
            }
        } label: {
            let isLoading = isGeneratingChapters || viewModel.isLoading
            actionButton(
                title: isLoading ? "Creating chapters..." : "Generate More Chapters",
                subtitle: isLoading ? "Creating new questions in the background - feel free to start your interview!" : "Add additional questions to extend your interview time",
                icon: isLoading ? "hourglass" : "plus.circle.fill",
                color: isLoading ? .orange : .purple,
                isLoading: isLoading
            )
        }
        .disabled(isGeneratingChapters || viewModel.isLoading)
        .buttonStyle(ActionButtonStyle())
    }
    
    private var interviewModeToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Interview Mode")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Toggle(isOn: Binding(
                get: { viewModel.currentProject.isSpeechInterview ?? false },
                set: { newValue in
                    Task {
                        await viewModel.toggleInterviewMode(isSpeech: newValue)
                    }
                }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.currentProject.isSpeechInterview ?? false ? "waveform.and.mic" : "text.book.closed.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.currentProject.isSpeechInterview ?? false ? .purple : .blue)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentProject.isSpeechInterview ?? false ? "Speaking Mode" : "Reading Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(viewModel.currentProject.isSpeechInterview ?? false ? "AI reads questions aloud" : "Read questions yourself")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            
            // Voice configuration section - only show when speaking mode is enabled
            if viewModel.currentProject.isSpeechInterview ?? false {
                voiceConfigurationSection
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var voiceConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 4)
            
            Button {
                showingSpeechConfig = true
            } label: {
                HStack {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Configure Voice Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Choose voice and speed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var postInterviewActions: some View {
        VStack(alignment: .leading, spacing: 20) {
            contentSection
            creationToolsSection
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Content")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    navigateToTranscript = true
                }) {
                    actionButton(
                        title: "View Transcript",
                        subtitle: transcriptSubtitle,
                        icon: "doc.text",
                        color: transcriptButtonColor
                    )
                }
                .disabled(!canViewTranscript)
                
                NavigationLink(destination: QuestionsAndAnswersView(project: viewModel.currentProject)) {
                    actionButton(
                        title: "Review All Questions",
                        subtitle: qaSubtitle,
                        icon: "questionmark.circle",
                        color: qaButtonColor
                    )
                }
            }
        }
    }
    
    private var creationToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Create & Share")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Button {
                showingAudiogramView = true
            } label: {
                actionButton(
                    title: "Create Audiogram",
                    subtitle: "Generate shareable video content",
                    icon: "play.rectangle.fill",
                    color: .blue
                )
            }
            .buttonStyle(ActionButtonStyle())
            
            Button {
                showingExportOptions = true
            } label: {
                actionButton(
                    title: "Export",
                    subtitle: "Export questions and answers as CSV or TXT",
                    icon: "square.and.arrow.up",
                    color: .orange
                )
            }
            .buttonStyle(ActionButtonStyle())
            .disabled(!canViewTranscript)
        }
    }
    
    private var projectHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Preset icon (if available)
                if let preset = viewModel.currentProject.preset {
                    Image(systemName: preset.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(categoryColor(for: preset.category))
                        .frame(width: 64, height: 64)
                        .background(categoryColor(for: preset.category).opacity(0.1))
                        .cornerRadius(16)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Project title
                    Text(viewModel.currentProject.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Preset badge (if available)
                    if let preset = viewModel.currentProject.preset {
                        HStack {
                            Text(categoryDisplayName(for: preset.category))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(categoryColor(for: preset.category).opacity(0.15))
                                .foregroundColor(categoryColor(for: preset.category))
                                .cornerRadius(8)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            // Description/topic section (if available from preset)
            if let preset = viewModel.currentProject.preset {
                Text("Based on the \"\(preset.title)\" interview guide")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(ColorTheme.cardBackground)
                    .cornerRadius(12)
            }
        }
    }
    
    private func categoryColor(for categoryId: String) -> Color {
        switch categoryId.lowercased() {
        case "self_reflection":
            return .blue
        case "gratitude":
            return .green
        case "relationships":
            return .pink
        case "career":
            return .orange
        case "creativity":
            return .purple
        case "wellness":
            return .mint
        case "expressive_writing":
            return .indigo
        default:
            return .gray
        }
    }
    
    private func categoryDisplayName(for categoryId: String) -> String {
        switch categoryId {
        case "expressive_writing": return "Expressive Writing"
        case "self_reflection": return "Self-Reflection"
        case "relationships": return "Relationships"
        case "career": return "Career"
        case "creativity": return "Creativity"
        case "wellness": return "Wellness"
        case "gratitude": return "Gratitude"
        default: return categoryId.capitalized
        }
    }
    
    private func actionButton(title: String, subtitle: String, icon: String, color: Color, isLoading: Bool = false) -> some View {
        HStack {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(title == "Start Recording" ? .largeTitle : .title2)
                        .foregroundColor(color)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isLoading {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(minHeight: 60)
        .background(actionButtonBackground(isLoading: isLoading, title: title, color: color))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(actionButtonBorder(title: title, color: color), lineWidth: 1)
        )
    }
    
    private func actionButtonBackground(isLoading: Bool, title: String, color: Color) -> Color {
        if isLoading {
            return Color(.systemGray5)
        } else if title == "Start Recording" {
            return color.opacity(0.1)
        } else {
            return Color(.systemGray6)
        }
    }
    
    private func actionButtonBorder(title: String, color: Color) -> Color {
        title == "Start Recording" ? color.opacity(0.3) : Color.clear
    }
}

// Custom button style for better responsiveness
struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .brightness(configuration.isPressed ? -0.05 : 0.0)
    }
}

struct NavigationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationTitle("Project Overview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
    }
}

struct ToolbarModifier: ViewModifier {
    let navigationSource: ProjectNavigationSource
    @Binding var navigateToHome: Bool
    @Binding var navigateToMyInterviews: Bool
    @Binding var showingDeleteAlert: Bool
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(backButtonTitle) {
                        switch navigationSource {
                        case .home:
                            navigateToHome = true
                        case .myInterviews:
                            navigateToMyInterviews = true
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
    }
    
    private var backButtonTitle: String {
        switch navigationSource {
        case .home:
            return "Home"
        case .myInterviews:
            return "My Interviews"
        }
    }
}

struct AlertsModifier: ViewModifier {
    @Binding var showingDeleteAlert: Bool
    @Binding var showError: Bool
    let errorMessage: String
    let viewModel: ProjectDetailViewModel
    
    func body(content: Content) -> some View {
        content
            .alert("Delete Project?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteProject()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this project? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
    }
}

struct NavigationDestinationsModifier: ViewModifier {
    @Binding var navigateToInterview: Bool
    @Binding var navigateToHome: Bool
    @Binding var navigateToMyInterviews: Bool
    @Binding var navigateToTranscript: Bool
    let currentProject: Project
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if #available(iOS 15.0, *) {
                        NavigationLink(
                            destination: InterviewSessionView(project: currentProject),
                            isActive: $navigateToInterview
                        ) { EmptyView() }
                        .hidden()
                        
                        NavigationLink(
                            destination: HomeView(),
                            isActive: $navigateToHome
                        ) { EmptyView() }
                        .hidden()
                        
                        NavigationLink(
                            destination: ProjectListView(),
                            isActive: $navigateToMyInterviews
                        ) { EmptyView() }
                        .hidden()
                        
                        NavigationLink(
                            destination: TranscriptView(project: currentProject),
                            isActive: $navigateToTranscript
                        ) { EmptyView() }
                        .hidden()
                    }
                }
            )
    }
}


struct SheetsModifier: ViewModifier {
    @Binding var showingSpeechConfig: Bool
    @Binding var showingAudiogramView: Bool
    @Binding var showingPodcastExportView: Bool
    @Binding var showingExportOptions: Bool
    let currentProject: Project
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingSpeechConfig) {
                SpeechInterviewConfigView(
                    customTopic: currentProject.title,
                    onProjectCreated: nil
                )
            }
            .sheet(isPresented: $showingAudiogramView) {
                // Audiogram feature removed during refactor
                Text("Audiogram feature is temporarily unavailable")
                    .padding()
            }
            .sheet(isPresented: $showingPodcastExportView) {
                // Podcast export feature removed during refactor
                Text("Podcast export feature is temporarily unavailable")
                    .padding()
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView(project: currentProject)
            }
    }
}

struct ViewModelObserversModifier: ViewModifier {
    let viewModel: ProjectDetailViewModel
    let dismiss: DismissAction
    @Binding var navigateToHome: Bool
    @Binding var navigateToMyInterviews: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.shouldDismissView) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
            .onChange(of: viewModel.shouldNavigateToHome) { shouldNavigateToHome in
                if shouldNavigateToHome {
                    navigateToHome = true
                }
            }
            .refreshable {
                await viewModel.refreshProject()
            }
    }
}

#Preview {
    NavigationView {
        ProjectDetailView(project: Project(
            id: 1,
            title: "Finding Resilience",
            createdAt: Date(),
            lastModifiedAt: Date(),
            lastAccessedAt: nil,
            preset: ProjectPresetInfo(
                title: "Finding Resilience",
                iconName: "shield.fill",
                category: "self_reflection"
            ),
            outline: nil,
            isSpeechInterview: false,
            presetId: 1,
            isOffline: nil
        ))
    }
}