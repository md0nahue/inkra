import Foundation

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class ProjectDetailViewModel: ObservableObject, ErrorHandling {
    @Published var currentProject: Project
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var isSyncing: Bool = false
    @Published var isStartingRecording: Bool = false
    @Published var shouldNavigateToInterview: Bool = false
    @Published var shouldDismissView: Bool = false
    @Published var shouldNavigateToHome: Bool = false
    @Published var hasAnyResponses: Bool = false
    
    private let projectService: ProjectServiceProtocol
    private let syncService: SyncService
    private let dataManager: DataManager
    private var pollingTimer: Timer?
    
    init(
        project: Project, 
        projectService: ProjectServiceProtocol = ProjectService(),
        syncService: SyncService = SyncService.shared,
        dataManager: DataManager = DataManager.shared
    ) {
        self.currentProject = project
        self.projectService = projectService
        self.syncService = syncService
        self.dataManager = dataManager
        
        // Load latest local data
        loadProjectFromLocal()
        
        // Trigger background sync if needed
        Task {
            await performBackgroundSyncIfNeeded()
        }
    }
    
    private func startPolling() {
        // Stop any existing timer before starting a new one
        stopPolling()

        // Only poll if the project outline is still generating
        guard currentProject.outline?.status == .generating else {
            print("✅ Project outline is stable. No polling needed.")
            return
        }

        print("🔄 Starting polling for project \(currentProject.id) with generating outline...")
        
        // Schedule a timer to refresh the project every 5 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                print("- Polling tick: Refreshing project...")
                await self?.refreshProject()
            }
        }
    }

    private func stopPolling() {
        if pollingTimer != nil {
            print("🛑 Stopping polling for project \(currentProject.id).")
            pollingTimer?.invalidate()
            pollingTimer = nil
        }
    }
    
    func loadProjectDetails() async {
        print("🔄 Loading project details for project \(currentProject.id)")
        
        // Show loading state if we don't have complete project data
        if currentProject.outline == nil {
            isLoading = true
        }
        
        // Load from local storage first for instant display
        loadProjectFromLocal()
        
        // Then sync with API in background
        await syncProjectData()
        
        // Check for responses after loading project data
        await checkForAnyResponses()
        
        isLoading = false
        
        // Start polling after the initial load
        startPolling()
    }
    
    private func loadProjectFromLocal() {
        if let localProject = dataManager.fetchProject(id: currentProject.id) {
            currentProject = localProject
            print("📱 Loaded project \(currentProject.id) from local storage")
        }
    }
    
    private func performBackgroundSyncIfNeeded() async {
        guard !isSyncing else { return }
        
        // Check if this project needs syncing
        if syncService.needsSync() {
            await syncProjectData()
        }
    }
    
    private func syncProjectData() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        await syncService.syncProject(currentProject.id)
        loadProjectFromLocal()
        
        isSyncing = false
    }
    
    func refreshProject() async {
        print("🔄 Force refreshing project \(currentProject.id)")
        print("🔍 Current project status before refresh: \(currentProject.outline?.status.rawValue ?? "nil")")
        // Don't set isLoading to true for background polls to avoid flashing the UI
        // isLoading = true 
        errorMessage = ""
        
        do {
            let updatedProject = try await projectService.getProject(id: currentProject.id)
            print("✅ Received updated project with status: \(updatedProject.outline?.status.rawValue ?? "nil")")
            
            // Clear any stale local data first
            dataManager.clearProject(id: currentProject.id)
            
            // Save to local storage
            dataManager.saveProject(updatedProject)
            dataManager.updateLastSyncedAt(for: updatedProject.id)
            
            // Update UI
            currentProject = updatedProject
            print("🔧 UI updated with status: \(currentProject.outline?.status.rawValue ?? "nil")")

            // After refreshing, check if we should continue polling
            startPolling()

        } catch {
            print("❌ Error refreshing project: \(error)")
            handleError(error)
            
            // Fall back to local data if available
            loadProjectFromLocal()
        }
        
        // isLoading = false
    }
    
    func addMoreChapters() async {
        isLoading = true
        errorMessage = ""
        
        do {
            _ = try await projectService.addMoreChapters(projectId: currentProject.id)
            
            // Don't immediately refresh - the chapters are being created
            // Instead, start polling to pick up the changes
            print("✅ Chapter generation initiated successfully")
            
            // Start polling to pick up the new chapters when they're ready
            startPolling()
            
        } catch {
            // Only show error if it's not a timeout
            if let urlError = error as? URLError, urlError.code == .timedOut {
                print("⏱️ Chapter generation is taking longer than expected, continuing in background")
                // Don't show error to user - chapters are likely still generating
                startPolling()
            } else {
                handleError(error)
            }
        }
        
        isLoading = false
    }
    
    func startRecording() async {
        guard !isStartingRecording else { return }
        
        isStartingRecording = true
        
        // 1. Navigate immediately for a snappy user experience.
        shouldNavigateToInterview = true
        
        // Project status is computed from outline status, no manual update needed
        
        isStartingRecording = false
    }
    
    func deleteProject() async {
        isLoading = true
        errorMessage = ""
        do {
            try await projectService.deleteProject(id: currentProject.id)
            // Signal the view to navigate to home
            shouldNavigateToHome = true
        } catch {
            handleError(error)
        }
        isLoading = false
    }
    
    func updateSpeechConfiguration(isSpeechEnabled: Bool, voiceId: String, speechRate: Int) async {
        // Store the speech configuration locally using UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(isSpeechEnabled, forKey: "project_\(currentProject.id)_speech_enabled")
        defaults.set(voiceId, forKey: "project_\(currentProject.id)_voice_id")
        defaults.set(speechRate, forKey: "project_\(currentProject.id)_speech_rate")
        
        print("💬 Speech configuration saved for project \(currentProject.id): enabled=\(isSpeechEnabled), voice=\(voiceId), rate=\(speechRate)")
    }
    
    func getSpeechConfiguration() -> (isEnabled: Bool, voiceId: String, speechRate: Int) {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.bool(forKey: "project_\(currentProject.id)_speech_enabled")
        let storedVoiceId = defaults.string(forKey: "project_\(currentProject.id)_voice_id")
        let voiceId: String
        if let storedVoiceId = storedVoiceId, PollyVoiceList.allVoices.contains(where: { $0.id == storedVoiceId }) {
            voiceId = storedVoiceId
        } else {
            voiceId = PollyVoiceList.defaultVoiceId // Defaults to "Matthew"
        }
        let speechRate = defaults.double(forKey: "project_\(currentProject.id)_speech_rate")
        
        // Default speech rate if not set (1.0 = normal speed)
        let finalSpeechRate = speechRate == 0 ? 1.0 : speechRate
        
        return (isEnabled: isEnabled, voiceId: voiceId, speechRate: Int(finalSpeechRate))
    }
    
    private func checkForAnyResponses() async {
        // Only check if we have an outline (questions exist)
        guard currentProject.outline != nil else {
            hasAnyResponses = false
            return
        }
        
        do {
            let response = try await projectService.getQuestionsWithResponses(projectId: currentProject.id)
            hasAnyResponses = response.questionsWithResponses > 0 || response.questionsWithTranscriptions > 0
        } catch {
            // If we can't load responses, assume false
            hasAnyResponses = false
            print("Failed to check for responses: \(error)")
        }
    }
    
    func toggleInterviewMode(isSpeech: Bool) async {
        errorMessage = ""
        
        do {
            // Update the project mode via API
            let updatedProject = try await projectService.updateInterviewMode(
                projectId: currentProject.id, 
                isSpeechInterview: isSpeech
            )
            
            // Update local project data
            currentProject = updatedProject
            dataManager.saveProject(updatedProject)
            
            print("✅ Interview mode updated to \(isSpeech ? "speech" : "reading") for project \(currentProject.id)")
            
        } catch {
            print("❌ Failed to toggle interview mode: \(error)")
            handleError(error)
        }
    }
    
    deinit {
        print("🗑️ ProjectDetailViewModel de-initialized. Stopping polling.")
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}