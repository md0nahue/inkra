import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct ProjectListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProjectListViewModel()
    @State private var showCreateProject = false
    @State private var projectToNavigate: Project?
    @State private var projectToStartInterview: Project?
    @State private var showDeleteConfirmation = false
    @State private var projectToDelete: ProjectSummary?
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                navigationContent
            }
        } else {
            NavigationView {
                navigationContent
            }
        }
    }
    
    @ViewBuilder
    private var navigationContent: some View {
            ZStack {
                // Cosmic Lofi background
                ColorTheme.auroraGradient
                    .ignoresSafeArea()
                
                VStack {
                    if viewModel.isLoading && viewModel.projects.isEmpty {
                        // Elegant loading state
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(ColorTheme.dreamyLavender)
                            
                            Text("Loading your projects...")
                                .font(Typography.bodyText)
                                .foregroundColor(ColorTheme.moonstoneGrey)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.projects.isEmpty {
                        // Sophisticated empty state
                        VStack(spacing: 32) {
                            VStack(spacing: 20) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(ColorTheme.dreamyLavender)
                                    .background(
                                        Circle()
                                            .fill(ColorTheme.celestialGlowGradient)
                                            .blur(radius: 15)
                                            .scaleEffect(1.5)
                                    )
                                
                                VStack(spacing: 12) {
                                    Text("Ready to Begin?")
                                        .font(Typography.screenTitle)
                                        .foregroundColor(ColorTheme.starlightWhite)
                                    
                                    Text("Share what's on your mind and we'll create a personalized interview experience")
                                        .font(Typography.bodyText)
                                        .foregroundColor(ColorTheme.moonstoneGrey)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                }
                            }
                            
                            Button("Create Your First Interview") {
                                showCreateProject = true
                            }
                            .pillButton(isPrimary: true)
                        }
                        .padding(.horizontal, 32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Elegant project list
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.projects) { projectSummary in
                                    Button(action: {
                                        print("🔄 Tapped project: \(projectSummary.title), ID: \(projectSummary.id)")
                                        if let fullProject = viewModel.fetchProject(id: projectSummary.id) {
                                            projectToNavigate = fullProject
                                        }
                                    }) {
                                        CosmicProjectCard(project: projectSummary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                // Load More button for older projects
                                if viewModel.hasMoreProjects {
                                    Button(action: {
                                        Task {
                                            await viewModel.loadMoreProjects()
                                        }
                                    }) {
                                        HStack {
                                            if viewModel.isLoadingMore {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .tint(ColorTheme.dreamyLavender)
                                                Text("Loading...")
                                                    .font(Typography.bodyText)
                                                    .foregroundColor(ColorTheme.moonstoneGrey)
                                            } else {
                                                Image(systemName: "arrow.down.circle")
                                                    .font(.system(size: 16, weight: .medium))
                                                Text("Load Older Projects")
                                                    .font(Typography.bodyText)
                                            }
                                        }
                                        .foregroundColor(ColorTheme.dreamyLavender)
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 24)
                                        .frame(maxWidth: .infinity)
                                        .cosmicLofiCard(glowEffect: false)
                                    }
                                    .disabled(viewModel.isLoadingMore)
                                    .padding(.top, 8)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 80)
                            .padding(.bottom, 40)
                        }
                        .refreshable {
                            await viewModel.loadProjects()
                        }
                    }
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(Typography.caption())
                            .foregroundColor(ColorTheme.error)
                            .padding(.horizontal)
                            .padding()
                            .cosmicLofiCard()
                            .padding(.horizontal, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay(
                // Custom header with menu and add buttons
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Home")
                                    .font(Typography.caption())
                            }
                            .foregroundColor(ColorTheme.dreamyLavender)
                        }
                        
                        Spacer()
                        
                        Text("My Interviews")
                            .font(Typography.cardTitle)
                            .foregroundColor(ColorTheme.starlightWhite)
                        
                        Spacer()
                        
                        // Spacer to balance the layout
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Home")
                                .font(Typography.caption())
                        }
                        .foregroundColor(ColorTheme.dreamyLavender)
                        .opacity(0) // Invisible to balance layout
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Spacer()
                },
                alignment: .top
            )
            .sheet(isPresented: $showCreateProject) {
                StreamlinedVoiceSelectionView()
            }
            .modifier(NavigationDestinationProjectModifier(
                item: $projectToNavigate,
                destination: { project in
                    ProjectDetailView(project: project, navigationSource: .myInterviews)
                }
            ))
            .modifier(NavigationDestinationProjectModifier(
                item: $projectToStartInterview,
                destination: { project in
                    InterviewSessionView(project: project)
                }
            ))
            .task {
            await viewModel.loadProjects()
        }
        .onAppear {
            Task {
                // This will refresh from local data, then sync with server
                await viewModel.loadProjects()
            }
        }
        .alert("Network Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Delete Project", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    Task {
                        do {
                            try await viewModel.deleteProject(id: project.id)
                        } catch {
                            print("Failed to delete project: \(error)")
                        }
                    }
                }
                projectToDelete = nil
            }
        } message: {
            if let project = projectToDelete {
                Text("Are you sure you want to delete '\(project.title)'? This action cannot be undone.")
            }
        }
    }
    
    private func deleteProjects(offsets: IndexSet) {
        guard let index = offsets.first else { return }
        projectToDelete = viewModel.projects[index]
        showDeleteConfirmation = true
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct ProjectRowView: View {
    let project: ProjectSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Preset icon (if available)
                if let preset = project.preset {
                    Image(systemName: preset.iconName)
                        .font(.title2)
                        .foregroundColor(categoryColor(for: preset.category))
                        .frame(width: 32)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(project.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Preset badge (if available)
                        if let preset = project.preset {
                            Text(categoryDisplayName(for: preset.category))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(categoryColor(for: preset.category).opacity(0.15))
                                .foregroundColor(categoryColor(for: preset.category))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    Text(project.topic)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                QuestionsProgressView(answeredCount: project.outline.answeredQuestionsCount ?? 0, 
                                     totalCount: project.outline.questionsCount)
            }
            
            HStack {
                Label("\(project.outline.questionsCount) total", systemImage: "questionmark.circle")
                Spacer()
                Label("\(project.outline.followupQuestionsCount) followup", systemImage: "arrow.turn.down.right")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Text("Modified \(RelativeDateTimeFormatter().localizedString(for: project.lastModifiedAt, relativeTo: Date()))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Ensures the whole area is tappable
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
}

@available(iOS 15.0, macOS 11.0, *)
struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(statusDisplayText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusDisplayText: String {
        switch status {
        case "outline_generating":
            return "Generating"
        case "outline_ready":
            return "Ready"
        case "recording":
            return "Recording"
        case "transcribing":
            return "Transcribing"
        case "completed":
            return "Completed"
        case "failed":
            return "Failed"
        default:
            return status.capitalized
        }
    }
    
    private var statusColor: Color {
        switch status {
        case "outline_generating", "transcribing":
            return .orange
        case "outline_ready":
            return .blue
        case "recording":
            return .purple
        case "completed":
            return .green
        case "failed":
            return .red
        default:
            return .gray
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct QuestionsProgressView: View {
    let answeredCount: Int
    let totalCount: Int
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(answeredCount)/\(totalCount)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(progressColor)
            
            Text("answered")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var progressColor: Color {
        let progress = totalCount > 0 ? Double(answeredCount) / Double(totalCount) : 0
        
        if progress == 1.0 {
            return .green
        } else if progress > 0.5 {
            return .blue
        } else if progress > 0 {
            return .orange
        } else {
            return .secondary
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct CreateProjectViewContainer: View {
    let onProjectCreated: (Project) -> Void
    @StateObject private var viewModel = CreateProjectViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        CreateProjectView()
            .environmentObject(viewModel)
            .onChange(of: viewModel.createdProject) { project in
                // When a project is created, notify the parent and dismiss
                if let project = project {
                    onProjectCreated(project)
                }
            }
            .onChange(of: viewModel.showError) { showError in
                // If there's an error and it's being shown, don't auto-dismiss
                // Let the user handle the error first
            }
    }
}

// Sophisticated Project Card Component
struct CosmicProjectCard: View {
    let project: ProjectSummary
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            VStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(project.title)
                        .font(Typography.bodyText)
                        .foregroundColor(ColorTheme.starlightWhite)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(statusText)
                        .font(Typography.metadata)
                        .foregroundColor(ColorTheme.moonstoneGrey)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ColorTheme.tertiaryBackground.opacity(0.5))
                        )
                }
                
                if !project.topic.isEmpty {
                    Text(project.topic)
                        .font(Typography.caption())
                        .foregroundColor(ColorTheme.moonstoneGrey)
                        .lineLimit(1)
                }
                
                HStack {
                    if project.isSpeechInterview == true {
                        Label("Audio Interview", systemImage: "mic.fill")
                            .font(Typography.metadata)
                            .foregroundColor(ColorTheme.sereneBlue)
                    } else {
                        Label("Text Interview", systemImage: "text.bubble.fill")
                            .font(Typography.metadata)
                            .foregroundColor(ColorTheme.pastelRose)
                    }
                    
                    Spacer()
                    
                    Text("\(project.outline.answeredQuestionsCount ?? 0)/\(project.outline.questionsCount)")
                        .font(Typography.metadata)
                        .foregroundColor(progressColor)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorTheme.moonstoneGrey)
                }
            }
        }
        .padding(20)
        .cosmicLofiCard(glowEffect: false)
    }
    
    private var statusColor: Color {
        let answered = project.outline.answeredQuestionsCount ?? 0
        let total = project.outline.questionsCount
        let progress = total > 0 ? Double(answered) / Double(total) : 0
        
        if progress == 1.0 {
            return ColorTheme.success
        } else if progress > 0 {
            return ColorTheme.dreamyLavender
        } else {
            return ColorTheme.moonstoneGrey
        }
    }
    
    private var statusText: String {
        let answered = project.outline.answeredQuestionsCount ?? 0
        let total = project.outline.questionsCount
        let progress = total > 0 ? Double(answered) / Double(total) : 0
        
        if progress == 1.0 {
            return "Complete"
        } else if progress > 0 {
            return "In Progress"
        } else {
            return "Ready"
        }
    }
    
    private var progressColor: Color {
        let answered = project.outline.answeredQuestionsCount ?? 0
        let total = project.outline.questionsCount
        let progress = total > 0 ? Double(answered) / Double(total) : 0
        
        if progress == 1.0 {
            return ColorTheme.success
        } else if progress > 0.5 {
            return ColorTheme.dreamyLavender
        } else if progress > 0 {
            return ColorTheme.sereneBlue
        } else {
            return ColorTheme.moonstoneGrey
        }
    }
}

#Preview {
    ProjectListView()
}