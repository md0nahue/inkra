import Foundation
import Combine

// Define a new notification name for data changes
extension Notification.Name {
    static let projectDataDidChange = Notification.Name("projectDataDidChange")
}

class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @MainActor @Published var isSyncing = false
    @MainActor @Published var lastSyncDate: Date?
    @MainActor @Published var hasMoreProjects = false
    
    private let dataManager: DataManager
    private let projectService: ProjectServiceProtocol
    private let transcriptService: TranscriptServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // Track recent project creation attempts to prevent duplicates
    private var recentCreationAttempts: [String: Date] = [:]
    private let creationCooldownPeriod: TimeInterval = 5.0
    
    // Sync intervals
    private let backgroundSyncInterval: TimeInterval = 300 // 5 minutes
    private let staleDataThreshold: TimeInterval = 600 // 10 minutes
    
    private var backgroundSyncTimer: Timer?
    
    init(
        projectService: ProjectServiceProtocol = ProjectService(),
        transcriptService: TranscriptServiceProtocol = TranscriptService(),
        dataManager: DataManager = DataManager.shared
    ) {
        self.dataManager = dataManager
        self.projectService = projectService
        self.transcriptService = transcriptService
        
        setupBackgroundSync()
    }
    
    deinit {
        backgroundSyncTimer?.invalidate()
    }
    
    // MARK: - Initial Sync
    
    @MainActor func performInitialSync() async {
        print("🔍 DEBUG: === SyncService.performInitialSync() CALLED ===")
        
        guard !isSyncing else { 
            print("🔍 DEBUG: Already syncing - skipping initial sync")
            return 
        }
        
        // Auth disabled in V1 - always proceed with local-only operation
        print("🔐 Auth disabled in V1 - operating in local-only mode")
        
        print("🔄 Starting initial sync...")
        isSyncing = true
        
        do {
            // Fetch first batch of recent projects (this includes full project data with questions)
            print("🔍 DEBUG: Calling projectService.getRecentProjects(limit: 5)...")
            let recentResponse = try await projectService.getRecentProjects(limit: 5, offset: 0)
            let projectSummaries = recentResponse.projects
            let hasMore = recentResponse.pagination.hasMore
            print("📥 Fetched \(projectSummaries.count) recent projects from batch API (has more: \(hasMore))")
            await MainActor.run {
                hasMoreProjects = hasMore
            }
            
            if projectSummaries.isEmpty {
                print("🚨 DEBUG: API returned ZERO project summaries")
                print("🔍 DEBUG: Response: \(recentResponse)")
            } else {
                print("🔍 DEBUG: API recent projects:")
                for (index, summary) in projectSummaries.enumerated() {
                    print("   [\(index)] \(summary.title) (ID: \(summary.id))")
                    print("        Questions: \(summary.outline.questionsCount)")
                }
            }
            
            // Convert summaries to full projects (the batch API already includes all needed data)
            var fullProjects: [Project] = []
            
            for summary in projectSummaries {
                // Create full project from the enriched summary data
                let fullProject = Project(
                    id: summary.id,
                    title: summary.title,
                    createdAt: summary.createdAt,
                    lastModifiedAt: summary.lastModifiedAt,
                    lastAccessedAt: summary.lastAccessedAt,
                    preset: summary.preset,
                    outline: convertSummaryToOutline(summary),
                    isSpeechInterview: summary.isSpeechInterview,
                    presetId: nil, // Could be added to API response if needed
                    isOffline: nil
                )
                
                fullProjects.append(fullProject)
                
                // Only fetch transcript if project is completed or transcribing
                if summary.outline.status == "completed" || summary.outline.status == "transcribing" {
                    do {
                        let transcript = try await transcriptService.getTranscript(projectId: summary.id)
                        dataManager.saveTranscript(transcript)
                    } catch {
                        // Project might not have a transcript yet
                        print("ℹ️ No transcript found for project \(summary.id)")
                    }
                }
                
                dataManager.updateLastSyncedAt(for: summary.id)
                print("✅ Synced project \(summary.id) with \(summary.outline.questionsCount) questions")
            }
            
            // Save all full projects to local database
            print("🔍 DEBUG: Saving \(fullProjects.count) full projects to DataManager...")
            dataManager.saveProjects(fullProjects)
            print("🔍 DEBUG: DataManager.saveProjects() completed")
            
            // Verify the data was saved
            let verificationProjects = dataManager.fetchProjects()
            print("🔍 DEBUG: Verification fetch returned \(verificationProjects.count) projects")
            
            if verificationProjects.count != fullProjects.count {
                print("🚨 DEBUG: SAVE VERIFICATION FAILED - Saved: \(fullProjects.count), Retrieved: \(verificationProjects.count)")
            }
            
            lastSyncDate = Date()
            print("✅ Initial sync completed successfully - synced \(fullProjects.count) projects with complete data")
            print("🔍 DEBUG: Set lastSyncDate to: \(lastSyncDate!)")
            
        } catch {
            print("❌ Initial sync failed: \(error)")
            print("🚨 DEBUG: Sync error details: \(error.localizedDescription)")
            
            if let networkError = error as? NetworkError {
                print("🚨 DEBUG: NetworkError: \(networkError)")
            }
        }
        
        print("🔍 DEBUG: Setting isSyncing = false")
        isSyncing = false
        print("🔍 DEBUG: === SyncService.performInitialSync() COMPLETED ===")
    }
    
    // MARK: - Background Sync
    
    private func setupBackgroundSync() {
        // Start background sync timer
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: backgroundSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performBackgroundSync()
            }
        }
    }
    
    @MainActor func performBackgroundSync() async {
        print("🔍 DEBUG: === SyncService.performBackgroundSync() CALLED ===")
        
        guard !isSyncing else { 
            print("🔍 DEBUG: Already syncing - skipping background sync")
            return 
        }
        
        // Auth disabled in V1 - always proceed with local-only operation
        print("🔐 Auth disabled in V1 - operating in local-only mode")
        
        print("🔄 Starting background sync...")
        isSyncing = true
        
        // Check current local data before sync
        let localProjectsBefore = dataManager.fetchProjects()
        print("🔍 DEBUG: Local projects before sync: \(localProjectsBefore.count)")
        
        // Get stale projects that need updating
        let staleProjects = dataManager.getStaleProjects(olderThan: staleDataThreshold)
        print("🔍 DEBUG: Found \(staleProjects.count) stale projects (threshold: \(staleDataThreshold)s)")
        
        if staleProjects.isEmpty {
            print("✅ All data is up to date")
            
            // But check if we have NO data at all
            if localProjectsBefore.isEmpty {
                print("🚨 DEBUG: CRITICAL - No stale projects but also NO local projects at all!")
                print("🔍 DEBUG: This suggests we need initial sync instead of background sync")
                
                // Force initial sync
                isSyncing = false
                await performInitialSync()
                return
            }
            
            isSyncing = false
            return
        }
        
        print("🔄 Syncing \(staleProjects.count) stale projects")
        
        // Update each stale project
        for localProject in staleProjects {
            do {
                let apiProject = try await projectService.getProject(id: localProject.id)
                dataManager.saveProject(apiProject)
                
                // Update transcript if project status changed to completed or transcribing
                if localProject.status != apiProject.status && 
                   (apiProject.status == .completed || apiProject.status == .transcribing) {
                    do {
                        let transcript = try await transcriptService.getTranscript(projectId: apiProject.id)
                        dataManager.saveTranscript(transcript)
                    } catch {
                        // Project might not have a transcript yet
                        print("ℹ️ No transcript found for project \(apiProject.id)")
                    }
                }
                
                dataManager.updateLastSyncedAt(for: apiProject.id)
                
            } catch {
                // Check if it's a 404/not found error - this might be a project that was just created
                // and hasn't fully propagated to the backend yet
                if let networkError = error as? NetworkError,
                   case .serverError(let statusCode) = networkError,
                   statusCode == 404 || statusCode == 500 {
                    print("ℹ️ Project \(localProject.id) not found on server yet - might be newly created")
                    // Don't mark this as synced, so we'll try again later
                } else {
                    print("⚠️ Failed to sync project \(localProject.id): \(error)")
                }
            }
        }
        
        // Verify sync results
        let localProjectsAfter = dataManager.fetchProjects()
        print("🔍 DEBUG: Local projects after sync: \(localProjectsAfter.count) (was \(localProjectsBefore.count))")
        
        lastSyncDate = Date()
        print("✅ Background sync completed")
        print("🔍 DEBUG: Set lastSyncDate to: \(lastSyncDate!)")
        
        isSyncing = false
        print("🔍 DEBUG: === SyncService.performBackgroundSync() COMPLETED ===")
    }
    
    // MARK: - Selective Sync
    
    func syncProject(_ projectId: Int) async {
        print("🔄 Syncing project \(projectId)...")
        
        do {
            let apiProject = try await projectService.getProject(id: projectId)
            await dataManager.saveProject(apiProject)
            
            // Sync transcript only if project is completed or transcribing
            if apiProject.status == .completed || apiProject.status == .transcribing {
                do {
                    let transcript = try await transcriptService.getTranscript(projectId: projectId)
                    await dataManager.saveTranscript(transcript)
                } catch {
                    // Project might not have a transcript yet
                    print("ℹ️ No transcript found for project \(projectId)")
                }
            }
            
            await dataManager.updateLastSyncedAt(for: projectId)
            print("✅ Project \(projectId) synced successfully")
            
        } catch {
            print("❌ Failed to sync project \(projectId): \(error)")
        }
    }
    
    func syncTranscripts(for projectId: Int) async {
        print("🔄 Syncing transcript for project \(projectId)...")
        
        // First check if the project is in a state that should have a transcript
        let localProject = await dataManager.fetchProject(id: projectId)
        guard localProject?.status == .completed || localProject?.status == .transcribing else {
            print("ℹ️ Project \(projectId) is not in a state that should have a transcript")
            return
        }
        
        do {
            let transcript = try await transcriptService.getTranscript(projectId: projectId)
            await dataManager.saveTranscript(transcript)
            print("✅ Transcript for project \(projectId) synced successfully")
            
        } catch {
            print("❌ Failed to sync transcripts for project \(projectId): \(error)")
        }
    }
    
    // MARK: - Data Operations with Sync
    
    func createProject(title: String) async throws -> Project {
        // Create project via API
        let apiProject = try await projectService.createProject(topic: title, isSpeechInterview: false, presetId: nil, presetUuid: nil, voiceId: nil, speechRate: nil, interviewLength: nil, questionCount: nil)
        
        // Save to local database
        await dataManager.saveProject(apiProject)
        await dataManager.updateLastSyncedAt(for: apiProject.id)
        
        print("✅ Created and synced project: \(title)")
        return apiProject
    }
    
    func createProject(title: String, isSpeechInterview: Bool, presetId: Int?, voiceId: String?, speechRate: Int?, interviewLength: String? = nil, questionCount: Int? = nil) async throws -> Project {
        print("🔄 DEBUG SyncService.createProject: Starting with title='\(title)', voiceId=\(voiceId ?? "nil"), speechRate=\(speechRate ?? 0)")
        
        // Check for recent duplicate creation attempts
        let now = Date()
        let projectKey = "\(title)_\(isSpeechInterview)_\(voiceId ?? "")_\(speechRate ?? 0)"
        
        if let lastAttempt = recentCreationAttempts[projectKey],
           now.timeIntervalSince(lastAttempt) < creationCooldownPeriod {
            print("🚨 DEBUG SyncService: Duplicate creation attempt blocked for '\(title)' - last attempt was \(now.timeIntervalSince(lastAttempt)) seconds ago")
            throw NSError(domain: "SyncService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Duplicate creation attempt blocked"])
        }
        
        // Record this creation attempt
        recentCreationAttempts[projectKey] = now
        
        // Clean up old entries (older than cooldown period)
        recentCreationAttempts = recentCreationAttempts.filter { _, date in
            now.timeIntervalSince(date) < creationCooldownPeriod
        }
        
        // Create project via API with all parameters - legacy method for backwards compatibility
        let apiProject = try await projectService.createProject(topic: title, isSpeechInterview: isSpeechInterview, presetId: presetId, presetUuid: nil, voiceId: voiceId, speechRate: speechRate, interviewLength: interviewLength, questionCount: questionCount)
        
        print("🔄 DEBUG SyncService.createProject: Project created via API - ID: \(apiProject.id), title: '\(apiProject.title)'")
        
        // Save to local database
        await dataManager.saveProject(apiProject)
        await dataManager.updateLastSyncedAt(for: apiProject.id)
        
        print("✅ DEBUG SyncService.createProject: Created and synced project: \(title) (ID: \(apiProject.id), speech: \(isSpeechInterview))")
        return apiProject
    }
    
    func createProject(title: String, isSpeechInterview: Bool, presetUuid: String?, voiceId: String?, speechRate: Int?, interviewLength: String? = nil, questionCount: Int? = nil) async throws -> Project {
        // Create project via API with UUID-based preset
        let apiProject = try await projectService.createProject(topic: title, isSpeechInterview: isSpeechInterview, presetId: nil, presetUuid: presetUuid, voiceId: voiceId, speechRate: speechRate, interviewLength: interviewLength, questionCount: questionCount)
        
        // Save to local database
        await dataManager.saveProject(apiProject)
        await dataManager.updateLastSyncedAt(for: apiProject.id)
        
        print("✅ Created and synced project: \(title) (speech: \(isSpeechInterview), preset: \(presetUuid ?? "none"))")
        return apiProject
    }
    
    func updateProject(_ project: Project) async throws -> Project {
        // Update via API first
        let updatedProject = try await projectService.updateProject(project)
        
        // Save to local database
        await dataManager.saveProject(updatedProject)
        await dataManager.updateLastSyncedAt(for: updatedProject.id)
        
        print("✅ Updated and synced project \(project.id)")
        return updatedProject
    }
    
    func deleteProject(_ projectId: Int) async throws {
        // Delete via API first
        try await projectService.deleteProject(id: projectId)
        
        // Remove from local database
        await dataManager.deleteProject(id: projectId)
        
        print("✅ Deleted project \(projectId) from API and local storage")
    }
    
    func addChapterToProject(_ projectId: Int, chapterTitle: String) async throws -> Project {
        // Add chapter via API
        let updatedProject = try await projectService.addChapter(projectId: projectId, title: chapterTitle)
        
        // Save to local database
        await dataManager.saveProject(updatedProject)
        await dataManager.updateLastSyncedAt(for: projectId)
        
        print("✅ Added chapter '\(chapterTitle)' to project \(projectId)")
        return updatedProject
    }
    
    
    // MARK: - Offline Support
    
    func getLocalProjects() async -> [Project] {
        return await dataManager.fetchProjects()
    }
    
    func getLocalProject(id: Int) async -> Project? {
        return await dataManager.fetchProject(id: id)
    }
    
    func getLocalTranscripts(for projectId: Int) async -> [Transcript] {
        return await dataManager.fetchTranscripts(for: projectId)
    }
    
    // MARK: - Sync Status
    
    @MainActor func needsSync() -> Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > staleDataThreshold
    }
    
    @MainActor func forceSyncAll() async {
        lastSyncDate = nil
        await performInitialSync()
    }
    
    // MARK: - Cache Management
    
    @MainActor func clearLocalData() async {
        dataManager.clearAllData()
        lastSyncDate = nil
        print("🗑️ Cleared all local data")
    }
    
    // MARK: - Helper Methods
    
    private func convertSummaryToOutline(_ summary: ProjectSummary) -> Outline? {
        // The batch API provides summary data, but for full outline we would need individual project calls
        // For now, create a minimal outline structure from the summary data
        // This is a placeholder - in practice, the batch API should return more detailed data
        return Outline(
            status: Outline.OutlineStatus(rawValue: summary.outline.status) ?? .generating,
            chapters: [] // Would need to be populated from batch API or individual calls if needed
        )
    }
    
    // MARK: - Debug Helpers
    
    @MainActor func printSyncStatus() {
        let projects = dataManager.fetchProjects()
        print("📊 Sync Status:")
        print("  - Local projects: \(projects.count)")
        print("  - Last sync: \(lastSyncDate?.formatted() ?? "Never")")
        print("  - Currently syncing: \(isSyncing)")
        print("  - Needs sync: \(needsSync())")
        
        let staleCount = dataManager.getStaleProjects(olderThan: staleDataThreshold).count
        print("  - Stale projects: \(staleCount)")
    }
}