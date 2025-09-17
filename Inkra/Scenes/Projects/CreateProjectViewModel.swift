import Foundation

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class CreateProjectViewModel: ObservableObject, ErrorHandling {
    @Published var topic: String = ""
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var createdProject: Project?
    @Published var showTextInput: Bool = false
    @Published var isSpeechInterview: Bool = false
    
    private let projectService: ProjectServiceProtocol
    private let maxTopicLength = 500
    private var lastCreationAttempt: Date?
    
    init(projectService: ProjectServiceProtocol = ProjectService()) {
        self.projectService = projectService
    }
    
    var canCreateProject: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        topic.count <= maxTopicLength &&
        !isLoading
    }
    
    func createProject() async {
        guard canCreateProject else { return }
        
        // Prevent duplicate creation attempts within 5 seconds
        let now = Date()
        if let lastAttempt = lastCreationAttempt,
           now.timeIntervalSince(lastAttempt) < 5.0 {
            print("🚨 DEBUG CreateProjectViewModel: Duplicate creation attempt blocked - last attempt was \(now.timeIntervalSince(lastAttempt)) seconds ago")
            return
        }
        
        lastCreationAttempt = now
        isLoading = true
        errorMessage = ""
        
        do {
            let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            let syncService = SyncService.shared
            createdProject = try await syncService.createProject(title: trimmedTopic, isSpeechInterview: isSpeechInterview, presetId: nil, voiceId: nil, speechRate: nil)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
}