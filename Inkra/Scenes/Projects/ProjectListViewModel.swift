import Foundation

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class ProjectListViewModel: ObservableObject {
    @Published var projects: [ProjectSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSyncing = false
    @Published var hasMoreProjects = false
    @Published var isLoadingMore = false
    
    private let projectService: ProjectServiceProtocol
    private let syncService: SyncService
    private let dataManager: DataManager
    
    init(
        projectService: ProjectServiceProtocol = ProjectService(),
        syncService: SyncService = SyncService.shared,
        dataManager: DataManager = DataManager.shared
    ) {
        print("🔍 DEBUG: === ProjectListViewModel.init() CALLED ===")
        self.projectService = projectService
        self.syncService = syncService
        self.dataManager = dataManager
        
        print("🔍 DEBUG: Services initialized - loading initial data...")
        // Load initial data from local storage
        loadProjectsFromLocal()
        print("🔍 DEBUG: After init loadProjectsFromLocal(): \(projects.count) projects")
        
        // Observe sync service for hasMoreProjects changes
        hasMoreProjects = syncService.hasMoreProjects
        
        // Trigger background sync if needed
        Task {
            print("🔍 DEBUG: Starting init background task...")
            await performInitialSyncIfNeeded()
            print("🔍 DEBUG: Init background task completed")
        }
        
        print("🔍 DEBUG: === ProjectListViewModel.init() COMPLETED ===")
    }
    
    func loadProjects() async {
        print("🔍 DEBUG: === ASYNC loadProjects() CALLED ===")
        print("🔍 DEBUG: Current projects count before reload: \(projects.count)")
        
        // Load from local first
        loadProjectsFromLocal()
        print("🔍 DEBUG: After loadProjectsFromLocal(): \(projects.count) projects")
        
        // Check if we still have no projects
        if projects.isEmpty {
            print("🚨 DEBUG: STILL NO PROJECTS after local load - investigating...")
            
            // Check Auth state
            let hasAuth = AuthService.shared.accessToken != nil
            print("🔍 DEBUG: Has auth token: \(hasAuth)")
            
            // Check sync service state
            print("🔍 DEBUG: SyncService needsSync: \(syncService.needsSync())")
            print("🔍 DEBUG: SyncService lastSyncDate: \(syncService.lastSyncDate?.description ?? "nil")")
            print("🔍 DEBUG: SyncService isSyncing: \(isSyncing)")
        }
        
        // Trigger background sync to refresh data
        await performBackgroundSync()
        print("🔍 DEBUG: After performBackgroundSync(): \(projects.count) projects")
        
        // Update hasMoreProjects from sync service
        hasMoreProjects = syncService.hasMoreProjects
        
        print("🔍 DEBUG: === COMPLETED loadProjects() - FINAL COUNT: \(projects.count) ===")
    }
    
    private func loadProjectsFromLocal() {
        print("🔍 DEBUG: === STARTING loadProjectsFromLocal() ===")
        
        // Step 1: Fetch from DataManager
        let localProjects = dataManager.fetchProjects()
        print("🔍 DEBUG: DataManager returned \(localProjects.count) projects")
        
        if localProjects.isEmpty {
            print("🚨 DEBUG: CRITICAL - DataManager returned EMPTY projects array")
            print("🔍 DEBUG: Is Core Data initialized? \(dataManager.isInitialized)")
        } else {
            print("🔍 DEBUG: Raw projects from DataManager:")
            for (index, project) in localProjects.enumerated() {
                print("   [\(index)] ID: \(project.id), Title: '\(project.title)', Status: \(project.status.rawValue)")
                print("        Created: \(project.createdAt), Modified: \(project.lastModifiedAt)")
                print("        Preset: \(project.preset?.title ?? "nil"), Outline: \(project.outline != nil ? "exists" : "nil")")
                if let outline = project.outline {
                    let questionCount = outline.chapters.flatMap { $0.sections }.flatMap { $0.questions }.count
                    print("        Outline: \(outline.chapters.count) chapters, \(questionCount) questions, Status: \(outline.status)")
                }
            }
        }
        
        // Step 2: Convert to ProjectSummary objects
        print("🔍 DEBUG: Converting to ProjectSummary objects...")
        let projectSummaries = localProjects.map { project in
            let summary = convertToProjectSummary(project)
            print("   Converted: \(project.title) -> Summary(id: \(summary.id), questions: \(summary.outline.questionsCount))")
            return summary
        }
        
        print("🔍 DEBUG: Converted \(localProjects.count) -> \(projectSummaries.count) summaries")
        
        // Step 3: Sort projects by last accessed, then by last modified
        let sortedProjects = projectSummaries.sorted { project1, project2 in
            // Projects with last_accessed_at come first
            switch (project1.lastAccessedAt, project2.lastAccessedAt) {
            case (.some(let date1), .some(let date2)):
                return date1 > date2
            case (.some(_), .none):
                return true
            case (.none, .some(_)):
                return false
            case (.none, .none):
                return project1.lastModifiedAt > project2.lastModifiedAt
            }
        }
        print("🔍 DEBUG: Sorted projects by lastAccessedAt, then lastModifiedAt")
        
        // Step 4: Update UI
        let oldCount = projects.count
        projects = sortedProjects
        print("🔍 DEBUG: Updated UI projects array: \(oldCount) -> \(projects.count)")
        
        // Step 5: Final validation
        if projects.isEmpty && !localProjects.isEmpty {
            print("🚨 DEBUG: CRITICAL ERROR - Had local projects but UI array is empty!")
            print("🚨 Local count: \(localProjects.count), Summary count: \(projectSummaries.count), Final count: \(projects.count)")
        }
        
        print("🔍 DEBUG: Final projects for UI:")
        for (index, project) in projects.enumerated() {
            print("   [\(index)] \(project.title) (ID: \(project.id)) - \(project.outline.questionsCount) questions")
        }
        
        print("🔍 DEBUG: === COMPLETED loadProjectsFromLocal() - TOTAL: \(projects.count) ===")
    }
    
    private func performInitialSyncIfNeeded() async {
        print("🔍 DEBUG: === performInitialSyncIfNeeded() CALLED ===")
        print("🔍 DEBUG: Current projects.isEmpty: \(projects.isEmpty)")
        print("🔍 DEBUG: SyncService.needsSync(): \(syncService.needsSync())")
        
        // Check if we have any local data
        if projects.isEmpty || syncService.needsSync() {
            print("🔄 Performing initial sync...")
            print("🔍 DEBUG: Reason: projects.isEmpty=\(projects.isEmpty), needsSync=\(syncService.needsSync())")
            
            isSyncing = true
            
            await syncService.performInitialSync()
            print("🔍 DEBUG: SyncService.performInitialSync() completed")
            
            loadProjectsFromLocal()
            print("🔍 DEBUG: After sync loadProjectsFromLocal(): \(projects.count) projects")
            
            isSyncing = false
        } else {
            print("🔍 DEBUG: No initial sync needed - have \(projects.count) projects and sync not needed")
        }
        
        print("🔍 DEBUG: === performInitialSyncIfNeeded() COMPLETED ===")
    }
    
    private func performBackgroundSync() async {
        print("🔍 DEBUG: === STARTING performBackgroundSync() ===")
        
        guard !isSyncing else { 
            print("🔍 DEBUG: Already syncing - skipping background sync")
            return 
        }
        
        print("🔍 DEBUG: Setting isSyncing = true")
        isSyncing = true
        
        let projectsBeforeSync = projects.count
        print("🔍 DEBUG: Projects before sync: \(projectsBeforeSync)")
        
        await syncService.performBackgroundSync()
        print("🔍 DEBUG: SyncService.performBackgroundSync() completed")
        
        loadProjectsFromLocal()
        let projectsAfterSync = projects.count
        print("🔍 DEBUG: Projects after sync and reload: \(projectsAfterSync) (was \(projectsBeforeSync))")
        
        if projectsAfterSync != projectsBeforeSync {
            print("🔍 DEBUG: Project count CHANGED during sync: \(projectsBeforeSync) -> \(projectsAfterSync)")
        }
        
        print("🔍 DEBUG: Setting isSyncing = false")
        isSyncing = false
        
        print("🔍 DEBUG: === COMPLETED performBackgroundSync() ===")
    }
    
    func refreshProjects() async {
        print("🔄 Force refreshing projects...")
        isLoading = true
        errorMessage = nil
        
        do {
            // Force sync from API
            let response = try await projectService.getProjects()
            
            // Update local storage
            let fullProjects = response.projects.compactMap { summary -> Project? in
                // We need to fetch full project details for local storage
                // For now, create minimal Project objects from summaries
                return Project(
                    id: summary.id,
                    title: summary.title,
                    createdAt: summary.createdAt,
                    lastModifiedAt: summary.lastModifiedAt,
                    lastAccessedAt: summary.lastAccessedAt,
                    preset: nil,
                    outline: nil, // Will be synced separately when needed
                    isSpeechInterview: false, // Default value for existing projects
                    presetId: nil, // Default value for existing projects
                    isOffline: nil // Default value for existing projects
                )
            }
            
            dataManager.saveProjects(fullProjects)
            
            // Update UI with sorted projects (API already returns them sorted by last accessed)
            projects = response.projects
            
        } catch {
            if let networkError = error as? NetworkError, case .unauthorized = networkError {
                // Handle 401 by logging out
                print("🔐 Unauthorized - logging out user")
                try? await AuthService.shared.logout()
                return
            }
            
            // Show error but keep local data if available
            errorMessage = "Failed to refresh projects: \(error.localizedDescription)"
            print("Error refreshing projects: \(error)")
            
            // Fall back to local data
            if projects.isEmpty {
                loadProjectsFromLocal()
            }
        }
        
        isLoading = false
    }
    
    func createProject(title: String) async throws -> ProjectSummary {
        isLoading = true
        errorMessage = nil
        
        do {
            let project = try await syncService.createProject(title: title)
            
            // Refresh local projects
            loadProjectsFromLocal()
            
            return convertToProjectSummary(project)
        } catch {
            errorMessage = "Failed to create project: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    func deleteProject(id: Int) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get question IDs for cache cleanup before deletion
            var questionIdsToCleanup: [Int] = []
            if let project = dataManager.fetchProject(id: id) {
                if let outline = project.outline {
                    for chapter in outline.chapters {
                        for section in chapter.sections {
                            for question in section.questions {
                                questionIdsToCleanup.append(question.id)
                            }
                        }
                    }
                }
            }
            
            try await syncService.deleteProject(id)
            
            // Clean up cached audio for this project
            if !questionIdsToCleanup.isEmpty {
                print("🗑️ Cleaning up cached audio for deleted project \(id)")
                AudioCacheService.shared.cleanupCacheForDeletedProject(questionIds: questionIdsToCleanup)
            }
            
            // Remove from local UI immediately
            projects.removeAll { $0.id == id }
            
        } catch {
            errorMessage = "Failed to delete project: \(error.localizedDescription)"
            
            // Refresh from local storage to restore UI state
            loadProjectsFromLocal()
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertToProjectSummary(_ project: Project) -> ProjectSummary {
        print("🔍 DEBUG: Converting Project(\(project.id)) '\(project.title)' to ProjectSummary")
        
        // Debug outline data
        if let outline = project.outline {
            let chapters = outline.chapters
            let sections = chapters.flatMap { $0.sections }
            let questions = sections.flatMap { $0.questions }
            let baseQuestions = questions.filter { !$0.isFollowUp }
            let followupQuestions = questions.filter { $0.isFollowUp }
            
            print("   Outline exists: \(chapters.count) chapters, \(sections.count) sections")
            print("   Questions: \(questions.count) total (\(baseQuestions.count) base + \(followupQuestions.count) followup)")
            print("   Status: \(outline.status.rawValue)")
            
            let outlineSummary = OutlineSummary(
                status: outline.status.rawValue,
                chaptersCount: chapters.count,
                sectionsCount: sections.count,
                questionsCount: questions.count,
                baseQuestionsCount: baseQuestions.count,
                followupQuestionsCount: followupQuestions.count,
                answeredQuestionsCount: nil // This will be populated from the API response
            )
            
            let summary = ProjectSummary(
                id: project.id,
                title: project.title,
                topic: project.title,
                createdAt: project.createdAt,
                lastModifiedAt: project.lastModifiedAt,
                lastAccessedAt: project.lastAccessedAt,
                preset: project.preset,
                outline: outlineSummary,
                isSpeechInterview: project.isSpeechInterview
            )
            
            print("   Created summary: \(summary.outline.questionsCount) questions")
            return summary
            
        } else {
            print("   ⚠️ WARNING: Project has NO outline - using defaults")
            
            let outlineSummary = OutlineSummary(
                status: "generating",
                chaptersCount: 0,
                sectionsCount: 0,
                questionsCount: 0,
                baseQuestionsCount: 0,
                followupQuestionsCount: 0,
                answeredQuestionsCount: nil
            )
            
            let summary = ProjectSummary(
                id: project.id,
                title: project.title,
                topic: project.title,
                createdAt: project.createdAt,
                lastModifiedAt: project.lastModifiedAt,
                lastAccessedAt: project.lastAccessedAt,
                preset: project.preset,
                outline: outlineSummary,
                isSpeechInterview: project.isSpeechInterview
            )
            
            print("   Created summary with empty outline")
            return summary
        }
    }
    
    // MARK: - Sync Status
    
    var needsSync: Bool {
        syncService.needsSync()
    }
    
    var lastSyncDate: Date? {
        syncService.lastSyncDate
    }
    
    // MARK: - Helper Methods for Navigation
    
    func fetchProject(id: Int) -> Project? {
        return dataManager.fetchProject(id: id)
    }
    
    func loadMoreProjects() async {
        guard hasMoreProjects && !isLoadingMore else { return }
        
        print("🔍 Loading more projects... current count: \(projects.count)")
        isLoadingMore = true
        errorMessage = nil
        
        do {
            let offset = projects.count
            let response = try await projectService.getRecentProjects(limit: 5, offset: offset)
            
            // Append new projects to existing list
            let newProjects = response.projects
            print("📥 Fetched \(newProjects.count) additional projects")
            
            projects.append(contentsOf: newProjects)
            hasMoreProjects = response.pagination.hasMore
            
            print("✅ Total projects now: \(projects.count), has more: \(hasMoreProjects)")
            
        } catch {
            if let networkError = error as? NetworkError, case .unauthorized = networkError {
                print("🔐 Unauthorized - logging out user")
                try? await AuthService.shared.logout()
                return
            }
            
            errorMessage = "Failed to load more projects: \(error.localizedDescription)"
            print("Error loading more projects: \(error)")
        }
        
        isLoadingMore = false
    }
}