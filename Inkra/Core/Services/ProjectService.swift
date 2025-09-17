import Foundation

protocol ProjectServiceProtocol {
    func createProject(topic: String, isSpeechInterview: Bool?, presetId: Int?, presetUuid: String?, voiceId: String?, speechRate: Int?, interviewLength: String?, questionCount: Int?) async throws -> Project
    func getProject(id: Int) async throws -> Project
    func getProjects() async throws -> ProjectListResponse
    func getRecentProjects(limit: Int, offset: Int) async throws -> RecentProjectsResponse
    func updateOutline(projectId: Int, updates: [OutlineUpdate]) async throws -> StandardAPIResponse
    func addMoreChapters(projectId: Int) async throws -> AddMoreChaptersResponse
    func updateProject(_ project: Project) async throws -> Project
    func deleteProject(id: Int) async throws
    func addChapter(projectId: Int, title: String) async throws -> Project
    func getFollowUpQuestions(projectId: Int, since: Date) async throws -> FollowUpQuestionsResponse
    func getAvailableQuestions(projectId: Int) async throws -> AvailableQuestionsResponse
    func getQuestionsWithResponses(projectId: Int) async throws -> QuestionsWithResponsesResponse
    func skipQuestion(projectId: Int, questionId: Int) async throws
    func getQuestionsDiff(projectId: Int, since: Date?) async throws -> QuestionsDiffResponse
    func updateInterviewMode(projectId: Int, isSpeechInterview: Bool) async throws -> Project
    func updateShareSettings(projectId: Int, isPublic: Bool, publicTitle: String?, publicDescription: String?) async throws -> ShareSettingsResponse
    func getShareUrl(projectId: Int) async throws -> ShareUrlResponse
}

class ProjectService: ProjectServiceProtocol {
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.networkService = networkService
    }
    
    func createProject(topic: String, isSpeechInterview: Bool? = nil, presetId: Int? = nil, presetUuid: String? = nil, voiceId: String? = nil, speechRate: Int? = nil, interviewLength: String? = nil, questionCount: Int? = nil) async throws -> Project {
        print("🏗️ DEBUG ProjectService.createProject: Starting with topic='\(topic)', isSpeechInterview=\(isSpeechInterview ?? false), interviewLength=\(interviewLength ?? "default"), questionCount=\(questionCount ?? 0)")
        
        let request = CreateProjectRequest(initialTopic: topic, isSpeechInterview: isSpeechInterview, presetId: presetId, presetUuid: presetUuid, voiceId: voiceId, speechRate: speechRate, interviewLength: interviewLength, questionCount: questionCount)
        let endpoint = ProjectEndpoint.create(request)
        
        print("🏗️ DEBUG ProjectService.createProject: About to make create request")
        let response = try await networkService.request(endpoint, responseType: CreateProjectResponse.self)
        
        print("🏗️ DEBUG ProjectService.createProject: Create response received - projectId: \(response.projectId)")
        
        // Add retry logic for fetching the full project data
        // Sometimes there's a timing issue where the project creation hasn't fully persisted yet
        var retryCount = 0
        let maxRetries = 5
        var fullProject: Project?
        
        while retryCount < maxRetries {
            retryCount += 1
            let waitTime = retryCount * 1_000_000_000 // 1, 2, 3, 4, 5 seconds
            
            print("🏗️ DEBUG ProjectService.createProject: Attempt \(retryCount)/\(maxRetries) - waiting \(retryCount) second(s) before fetching")
            try await Task.sleep(nanoseconds: UInt64(waitTime))
            
            do {
                print("🏗️ DEBUG ProjectService.createProject: Fetching full project data for ID: \(response.projectId)")
                fullProject = try await getProject(id: response.projectId)
                print("🏗️ DEBUG ProjectService.createProject: Successfully retrieved full project - ID: \(fullProject!.id), title: '\(fullProject!.title)'")
                break
            } catch {
                print("🏗️ DEBUG ProjectService.createProject: Attempt \(retryCount) failed: \(error)")
                if retryCount == maxRetries {
                    print("🏗️ DEBUG ProjectService.createProject: All retries exhausted, throwing error")
                    throw error
                }
            }
        }
        
        guard let project = fullProject else {
            throw NSError(domain: "ProjectService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch project after creation"])
        }
        
        return project
    }
    
    func getProject(id: Int) async throws -> Project {
        print("📄 DEBUG ProjectService.getProject: Fetching project with ID: \(id)")
        let endpoint = ProjectEndpoint.get(id)
        let project = try await networkService.request(endpoint, responseType: Project.self)
        print("📄 DEBUG ProjectService.getProject: Successfully fetched project - ID: \(project.id), title: '\(project.title)'")
        return project
    }
    
    func getProjects() async throws -> ProjectListResponse {
        let endpoint = ProjectEndpoint.list
        return try await networkService.request(endpoint, responseType: ProjectListResponse.self)
    }
    
    func getRecentProjects(limit: Int = 5, offset: Int = 0) async throws -> RecentProjectsResponse {
        let endpoint = ProjectEndpoint.recent(limit: limit, offset: offset)
        return try await networkService.request(endpoint, responseType: RecentProjectsResponse.self)
    }
    
    func updateOutline(projectId: Int, updates: [OutlineUpdate]) async throws -> StandardAPIResponse {
        let request = UpdateOutlineRequest(updates: updates)
        let endpoint = ProjectEndpoint.updateOutline(projectId, request)
        return try await networkService.request(endpoint, responseType: StandardAPIResponse.self)
    }
    
    func addMoreChapters(projectId: Int) async throws -> AddMoreChaptersResponse {
        let endpoint = ProjectEndpoint.addMoreChapters(projectId)
        return try await networkService.request(endpoint, responseType: AddMoreChaptersResponse.self)
    }
    
    func updateProject(_ project: Project) async throws -> Project {
        let endpoint = ProjectEndpoint.update(project.id, project)
        return try await networkService.request(endpoint, responseType: Project.self)
    }
    
    func deleteProject(id: Int) async throws {
        let endpoint = ProjectEndpoint.delete(id)
        let _: StandardAPIResponse = try await networkService.request(endpoint, responseType: StandardAPIResponse.self)
    }
    
    func addChapter(projectId: Int, title: String) async throws -> Project {
        let request = AddChapterRequest(title: title)
        let endpoint = ProjectEndpoint.addChapter(projectId, request)
        return try await networkService.request(endpoint, responseType: Project.self)
    }
    
    func getFollowUpQuestions(projectId: Int, since: Date) async throws -> FollowUpQuestionsResponse {
        let endpoint = ProjectEndpoint.followUpQuestions(projectId, since)
        return try await networkService.request(endpoint, responseType: FollowUpQuestionsResponse.self)
    }
    
    func getAvailableQuestions(projectId: Int) async throws -> AvailableQuestionsResponse {
        print("❓ DEBUG ProjectService.getAvailableQuestions: Fetching questions for projectId: \(projectId)")
        let endpoint = ProjectEndpoint.availableQuestions(projectId)
        let response = try await networkService.request(endpoint, responseType: AvailableQuestionsResponse.self)
        print("❓ DEBUG ProjectService.getAvailableQuestions: Received \(response.questions.count) questions for projectId: \(projectId)")
        return response
    }
    
    func getQuestionsWithResponses(projectId: Int) async throws -> QuestionsWithResponsesResponse {
        let endpoint = ProjectEndpoint.questionsWithResponses(projectId)
        return try await networkService.request(endpoint, responseType: QuestionsWithResponsesResponse.self)
    }
    
    func skipQuestion(projectId: Int, questionId: Int) async throws {
        let endpoint = ProjectEndpoint.skipQuestion(projectId, questionId)
        let _: StandardAPIResponse = try await networkService.request(endpoint, responseType: StandardAPIResponse.self)
    }
    
    func getQuestionsDiff(projectId: Int, since: Date?) async throws -> QuestionsDiffResponse {
        print("📊 DEBUG ProjectService.getQuestionsDiff: Fetching questions diff for projectId: \(projectId), since: \(String(describing: since))")
        let endpoint = ProjectEndpoint.questionsDiff(projectId, since)
        let response = try await networkService.request(endpoint, responseType: QuestionsDiffResponse.self)
        print("📊 DEBUG ProjectService.getQuestionsDiff: Received \(response.newQuestionsCount) new questions")
        return response
    }
    
    func updateInterviewMode(projectId: Int, isSpeechInterview: Bool) async throws -> Project {
        print("🔄 DEBUG ProjectService.updateInterviewMode: Updating mode for projectId: \(projectId) to speech: \(isSpeechInterview)")
        let request = UpdateInterviewModeRequest(isSpeechInterview: isSpeechInterview)
        let endpoint = ProjectEndpoint.updateInterviewMode(projectId, request)
        let response = try await networkService.request(endpoint, responseType: Project.self)
        print("🔄 DEBUG ProjectService.updateInterviewMode: Successfully updated mode for projectId: \(projectId)")
        return response
    }
    
    func updateShareSettings(projectId: Int, isPublic: Bool, publicTitle: String?, publicDescription: String?) async throws -> ShareSettingsResponse {
        print("🔗 DEBUG ProjectService.updateShareSettings: Updating sharing for projectId: \(projectId), public: \(isPublic)")
        let request = UpdateShareSettingsRequest(isPublic: isPublic, publicTitle: publicTitle, publicDescription: publicDescription)
        let endpoint = ProjectEndpoint.updateShareSettings(projectId, request)
        let response = try await networkService.request(endpoint, responseType: ShareSettingsResponse.self)
        print("🔗 DEBUG ProjectService.updateShareSettings: Successfully updated sharing for projectId: \(projectId)")
        return response
    }
    
    func getShareUrl(projectId: Int) async throws -> ShareUrlResponse {
        print("🔗 DEBUG ProjectService.getShareUrl: Getting share URL for projectId: \(projectId)")
        let endpoint = ProjectEndpoint.getShareUrl(projectId)
        let response = try await networkService.request(endpoint, responseType: ShareUrlResponse.self)
        print("🔗 DEBUG ProjectService.getShareUrl: Retrieved share URL for projectId: \(projectId)")
        return response
    }
}

enum ProjectEndpoint: APIEndpoint {
    case create(CreateProjectRequest)
    case get(Int)
    case list
    case recent(limit: Int, offset: Int)
    case updateOutline(Int, UpdateOutlineRequest)
    case addMoreChapters(Int)
    case update(Int, Project)
    case delete(Int)
    case addChapter(Int, AddChapterRequest)
    case followUpQuestions(Int, Date)
    case availableQuestions(Int)
    case questionsWithResponses(Int)
    case skipQuestion(Int, Int)
    case questionsDiff(Int, Date?)
    case updateInterviewMode(Int, UpdateInterviewModeRequest)
    case updateShareSettings(Int, UpdateShareSettingsRequest)
    case getShareUrl(Int)
    
    var path: String {
        switch self {
        case .create:
            return "/api/projects"
        case .get(let id):
            return "/api/projects/\(id)"
        case .list:
            return "/api/projects"
        case .recent(let limit, let offset):
            return "/api/projects/recent?limit=\(limit)&offset=\(offset)"
        case .updateOutline(let id, _):
            return "/api/projects/\(id)/outline"
        case .addMoreChapters(let id):
            return "/api/projects/\(id)/add_more_chapters"
        case .update(let id, _):
            return "/api/projects/\(id)"
        case .delete(let id):
            return "/api/projects/\(id)"
        case .addChapter(let id, _):
            return "/api/projects/\(id)/chapters"
        case .followUpQuestions(let id, let since):
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestamp = formatter.string(from: since)
            return "/api/projects/\(id)/follow_up_questions?since=\(timestamp.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        case .availableQuestions(let id):
            return "/api/projects/\(id)/available_questions"
        case .questionsWithResponses(let id):
            return "/api/projects/\(id)/questions_with_responses"
        case .skipQuestion(let projectId, let questionId):
            return "/api/projects/\(projectId)/questions/\(questionId)/skip"
        case .questionsDiff(let id, let since):
            if let since = since {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let timestamp = formatter.string(from: since)
                return "/api/projects/\(id)/questions/diff?since=\(timestamp.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            } else {
                return "/api/projects/\(id)/questions/diff"
            }
        case .updateInterviewMode(let id, let request):
            return "/api/projects/\(id)/interview_mode?is_speech_interview=\(request.isSpeechInterview)"
        case .updateShareSettings(let id, _):
            return "/api/projects/\(id)/share_settings"
        case .getShareUrl(let id):
            return "/api/projects/\(id)/share_url"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .create:
            return .POST
        case .get, .list, .recent, .followUpQuestions, .availableQuestions, .questionsWithResponses, .questionsDiff, .getShareUrl:
            return .GET
        case .updateOutline, .updateShareSettings:
            return .PATCH
        case .addMoreChapters:
            return .POST
        case .update:
            return .PUT
        case .delete:
            return .DELETE
        case .addChapter:
            return .POST
        case .skipQuestion, .updateInterviewMode:
            return .POST
        }
    }
    
    var body: Codable? {
        switch self {
        case .create(let request):
            return request
        case .get, .list, .recent, .followUpQuestions, .availableQuestions, .questionsWithResponses, .questionsDiff, .getShareUrl:
            return nil
        case .updateOutline(_, let request):
            return request
        case .addMoreChapters:
            return nil
        case .update(_, let project):
            return project
        case .delete:
            return nil
        case .addChapter(_, let request):
            return request
        case .skipQuestion:
            return nil
        case .updateInterviewMode:
            return nil
        case .updateShareSettings(_, let request):
            return request
        }
    }
}