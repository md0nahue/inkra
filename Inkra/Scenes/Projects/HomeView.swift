import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct HomeView: View {
    @State private var navigateToProject: Project?
    @State private var showInterviewTypeSelection = false
    @State private var showMyInterviews = false
    @State private var showMenu = false
    @State private var showVoiceSettings = false
    @State private var showDailyQuestions = false
    @State private var showDailyQuestionsInterview = false
    @State private var recentInterviews: [RecentProject] = []
    @StateObject private var voiceService = VoiceService.shared
    
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
                // Cosmic Lofi aurora background
                ColorTheme.auroraGradient
                    .ignoresSafeArea()
                
                // Ambient celestial glow effects
                ZStack {
                    ColorTheme.celestialGlowGradient
                        .blur(radius: 50)
                        .offset(x: -100, y: -200)
                        .opacity(0.3)
                    
                    ColorTheme.celestialGlowGradient
                        .blur(radius: 60)
                        .offset(x: 150, y: 100)
                        .opacity(0.2)
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Sophisticated logo area with minimal design
                        VStack(spacing: 20) {
                            // Refined logo treatment
                            Image("octopus-logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(ColorTheme.celestialGlow.opacity(0.3), lineWidth: 1)
                                )
                                .background(
                                    Circle()
                                        .fill(ColorTheme.celestialGlowGradient)
                                        .blur(radius: 10)
                                        .scaleEffect(1.2)
                                )
                            
                            // Elegant app title
                            Text("Inkra")
                                .font(Typography.screenTitle)
                                .foregroundColor(ColorTheme.starlightWhite)
                                .tracking(2)
                            
                            Text("AI-Powered Interviews")
                                .font(Typography.caption(12))
                                .foregroundColor(ColorTheme.moonstoneGrey)
                                .tracking(1)
                        }
                        .padding(.top, 40)
                        
                        // Main CTA - Magical Interview Start
                        VStack(spacing: 16) {
                            CosmicActionButton(
                                title: "Start New Interview",
                                icon: "waveform.and.mic",
                                isPrimary: true,
                                action: { showInterviewTypeSelection = true }
                            )

                            // Quick Settings Row
                            HStack(spacing: 12) {
                                Button(action: { showVoiceSettings = true }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "speaker.wave.2")
                                        Text("Voice")
                                    }
                                    .font(.caption)
                                    .foregroundColor(ColorTheme.primaryAccent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(ColorTheme.cardBackground)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(ColorTheme.primaryAccent.opacity(0.3), lineWidth: 1)
                                    )
                                }

                                Button(action: { showDailyQuestionsInterview = true }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "questionmark.circle")
                                        Text("Daily Questions")
                                    }
                                    .font(.caption)
                                    .foregroundColor(ColorTheme.primaryAccent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(ColorTheme.cardBackground)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(ColorTheme.primaryAccent.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .contextMenu {
                                    Button(action: { showDailyQuestionsInterview = true }) {
                                        Label("Start Daily Interview", systemImage: "play.circle")
                                    }

                                    Button(action: { showDailyQuestions = true }) {
                                        Label("Edit Questions", systemImage: "pencil")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Secondary Actions
                        HStack(spacing: 16) {
                            Button(action: { showMyInterviews = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                    Text("My Interviews")
                                }
                                .font(.subheadline)
                                .foregroundColor(ColorTheme.starlightWhite)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(ColorTheme.cardBackground)
                                .cornerRadius(25)
                            }

                            Button(action: { showMenu = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "gearshape")
                                    Text("Settings")
                                }
                                .font(.subheadline)
                                .foregroundColor(ColorTheme.starlightWhite)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(ColorTheme.cardBackground)
                                .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Elegant recent sections
                        VStack(spacing: 24) {
                            // Recent Interviews - only show if there are interviews
                            if !recentInterviews.isEmpty {
                                RecentSection(
                                    title: "Recent Interviews",
                                    items: Array(recentInterviews.prefix(2)),
                                    emptyMessage: "", // Not used since we check isEmpty above
                                    onItemTap: { interview in
                                        navigateToProjectById(interview.id)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadRecentItems()
                await voiceService.fetchAndCacheVoices()
            }
            .refreshable {
                await loadRecentItems()
            }
            .modifier(NavigationDestinationProjectModifier(
                item: $navigateToProject,
                destination: { project in
                    ProjectDetailView(project: project, navigationSource: .home)
                }
            ))
            .modifier(NavigationDestinationBoolModifier(
                isPresented: $showInterviewTypeSelection,
                destination: { StreamlinedVoiceSelectionView() }
            ))
            .modifier(NavigationDestinationBoolModifier(
                isPresented: $showMyInterviews,
                destination: { ProjectListView() }
            ))
            .sheet(isPresented: $showMenu) {
                SettingsView()
            }
            .sheet(isPresented: $showVoiceSettings) {
                VoiceSettingsView()
            }
            .sheet(isPresented: $showDailyQuestions) {
                DailyQuestionsView()
            }
            .fullScreenCover(isPresented: $showDailyQuestionsInterview) {
                DailyQuestionInterviewView()
            }
    }
    
    private func loadRecentItems() async {
        // Load recent interviews
        do {
            let response = try await ProjectService().getRecentProjects()
            await MainActor.run {
                self.recentInterviews = response.projects.map { project in
                    RecentProject(
                        id: project.id,
                        title: project.title,
                        topic: project.topic,
                        lastAccessedAt: project.lastAccessedAt?.ISO8601Format(),
                        isSpeechInterview: project.isSpeechInterview ?? false,
                        status: project.outline.status
                    )
                }
            }
        } catch {
            ErrorLogger.shared.logError(error, context: "HomeView.loadRecentInterviews")
        }
        
        // VibeLog functionality removed during refactor
        // Recent trackers loading disabled
    }
    
    private func navigateToProjectById(_ projectId: Int) {
        Task {
            do {
                let project = try await ProjectService().getProject(id: projectId)
                await MainActor.run {
                    self.navigateToProject = project
                }
            } catch {
                ErrorLogger.shared.logError(error, context: "HomeView.navigateToProjectById")
            }
        }
    }
    
    static func formatRelativeTime(_ dateString: String?) -> String {
        guard let dateString = dateString,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return "recently"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Sophisticated Cosmic Action Button
struct CosmicActionButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isPrimary ? ColorTheme.starlightWhite : ColorTheme.primaryText)
                
                Text(title)
                    .font(Typography.buttonLabel)
                    .foregroundColor(isPrimary ? ColorTheme.starlightWhite : ColorTheme.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    if isPrimary {
                        // Primary button with dreamy lavender gradient
                        RoundedRectangle(cornerRadius: 999)
                            .fill(
                                LinearGradient(
                                    colors: [ColorTheme.dreamyLavender, ColorTheme.dreamyLavender.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Subtle glow effect
                        RoundedRectangle(cornerRadius: 999)
                            .fill(ColorTheme.dreamyLavender.opacity(0.3))
                            .blur(radius: 8)
                            .scaleEffect(1.1)
                    } else {
                        // Secondary button with cosmic card style
                        RoundedRectangle(cornerRadius: 999)
                            .fill(ColorTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(ColorTheme.cardBorder, lineWidth: 1)
                            )
                    }
                }
            )
        }
        .shadow(color: ColorTheme.shadowColor, radius: 6, x: 0, y: 3)
    }
}

// Elegant Recent Section Component
struct RecentSection<Item>: View where Item: Any {
    let title: String
    let items: [Item]
    let emptyMessage: String
    let onItemTap: (Item) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(Typography.cardTitle)
                .foregroundColor(ColorTheme.starlightWhite)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    
                    if let interview = item as? RecentProject {
                        RecentInterviewCard(interview: interview)
                            .onTapGesture { onItemTap(item) }
                    }
                }
            }
        }
    }
}


// Sophisticated Recent Interview Card
struct RecentInterviewCard: View {
    let interview: RecentProject
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(interview.status == "completed" ? ColorTheme.success : ColorTheme.dreamyLavender)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(interview.title)
                    .font(Typography.bodyText)
                    .foregroundColor(ColorTheme.starlightWhite)
                    .lineLimit(1)
                
                Text("Last accessed \(HomeView.formatRelativeTime(interview.lastAccessedAt))")
                    .font(Typography.metadata)
                    .foregroundColor(ColorTheme.moonstoneGrey)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ColorTheme.moonstoneGrey)
        }
        .padding(20)
        .cosmicLofiCard()
    }
}


// Response Models
struct RecentProjectsResponse: Codable {
    let projects: [ProjectSummary]
    let pagination: PaginationInfo
}

struct PaginationInfo: Codable {
    let totalCount: Int
    let hasMore: Bool
    let currentOffset: Int
    let currentLimit: Int
}

struct RecentProject: Codable {
    let id: Int
    let title: String
    let topic: String
    let lastAccessedAt: String?
    let isSpeechInterview: Bool
    let status: String
}


// Custom modifiers for iOS 15 compatibility
struct NavigationDestinationBoolModifier<Destination: View>: ViewModifier {
    @Binding var isPresented: Bool
    let destination: () -> Destination
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .navigationDestination(isPresented: $isPresented, destination: destination)
        } else {
            content
                .background(
                    NavigationLink(
                        destination: destination(),
                        isActive: $isPresented,
                        label: { EmptyView() }
                    ).hidden()
                )
        }
    }
}


#Preview {
    HomeView()
}