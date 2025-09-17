import Foundation
import Combine

@MainActor
class QuestionRepository: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var questions: [InterviewQuestion] = []
    @Published private(set) var isPolling: Bool = false
    @Published private(set) var lastPollTime: Date?
    
    // MARK: - Publishers
    
    let newQuestionsPublisher = PassthroughSubject<[InterviewQuestion], Never>()
    
    // MARK: - Properties
    
    private let projectId: Int
    private let projectService: ProjectServiceProtocol
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 15.0
    private var lastQuestionTimestamp: Date?
    private let questionCache = NSCache<NSString, NSArray>()
    
    // MARK: - Queue Management
    
    private var questionQueue: [InterviewQuestion] = []
    private var processedQuestionIds: Set<Int> = []
    private var pendingQuestionCount: Int = 0
    
    // MARK: - Initialization
    
    init(projectId: Int, projectService: ProjectServiceProtocol) {
        self.projectId = projectId
        self.projectService = projectService
        
        // Configure cache
        questionCache.countLimit = 100
        
        print("[QuestionRepository] Initialized for project: \(projectId)")
    }
    
    // MARK: - Public API
    
    func loadInitialQuestions() async throws -> [InterviewQuestion] {
        print("[QuestionRepository] Loading initial questions...")
        
        // Check cache first
        if let cachedQuestions = getCachedQuestions() {
            print("[QuestionRepository] Found \(cachedQuestions.count) cached questions")
            self.questions = cachedQuestions
            self.questionQueue = cachedQuestions
            return cachedQuestions
        }
        
        // Fetch from API
        do {
            let response = try await projectService.getAvailableQuestions(projectId: projectId)
            let questions = response.questions
            
            // Process and cache questions
            processNewQuestions(questions)
            cacheQuestions(questions)
            
            print("[QuestionRepository] Loaded \(questions.count) questions from API")
            return questions
            
        } catch {
            print("[QuestionRepository] Failed to load initial questions: \(error)")
            throw error
        }
    }
    
    func startPolling() async {
        guard !isPolling else { return }
        
        isPolling = true
        lastPollTime = Date()
        
        // Start polling timer
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollForNewQuestions()
            }
        }
        
        print("[QuestionRepository] Started polling (interval: \(pollingInterval)s)")
    }
    
    func stopPolling() async {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isPolling = false
        
        print("[QuestionRepository] Stopped polling")
    }
    
    func getAllQuestions() async -> [InterviewQuestion] {
        return questionQueue
    }
    
    func hasPendingQuestions() async -> Bool {
        return pendingQuestionCount > 0
    }
    
    func markQuestionAnswered(_ questionId: Int) {
        processedQuestionIds.insert(questionId)
        
        // Notify API that question was answered for better follow-up generation
        Task {
            // Skip the question to mark it as answered
            try? await projectService.skipQuestion(projectId: projectId, questionId: questionId)
        }
    }
    
    // MARK: - Private Methods
    
    private func pollForNewQuestions() async {
        print("[QuestionRepository] Polling for new questions...")
        
        do {
            // Use diff endpoint to get only new questions
            let timestamp = lastQuestionTimestamp ?? Date().addingTimeInterval(-60)
            let newQuestions = try await fetchQuestionsDiff(since: timestamp)
            
            if !newQuestions.isEmpty {
                print("[QuestionRepository] Received \(newQuestions.count) new questions")
                mergeNewQuestions(newQuestions)
                lastQuestionTimestamp = Date()
                
                // Notify subscribers
                newQuestionsPublisher.send(newQuestions)
            } else {
                print("[QuestionRepository] No new questions available")
            }
            
            lastPollTime = Date()
            
        } catch {
            print("[QuestionRepository] Polling error: \(error)")
        }
    }
    
    private func fetchQuestionsDiff(since timestamp: Date) async throws -> [InterviewQuestion] {
        // Call the new diff endpoint
        let response = try await projectService.getQuestionsDiff(projectId: projectId, since: timestamp)
        
        // Filter to only new questions not in our processed set
        let newQuestions = response.questions.filter { question in
            !processedQuestionIds.contains(question.id) &&
            !questionQueue.contains(where: { $0.id == question.id })
        }
        
        return newQuestions
    }
    
    private func processNewQuestions(_ questions: [InterviewQuestion]) {
        self.questions = questions
        self.questionQueue = questions
        
        // Track which questions we've seen
        questions.forEach { question in
            if !processedQuestionIds.contains(question.id) {
                // New question that hasn't been processed yet
            }
        }
    }
    
    private func mergeNewQuestions(_ newQuestions: [InterviewQuestion]) {
        // Intelligently merge new questions into the queue
        
        for question in newQuestions {
            // Skip if already in queue
            guard !questionQueue.contains(where: { $0.id == question.id }) else {
                continue
            }
            
            // Determine insertion point based on question type
            if question.isFollowUp {
                // Insert follow-up questions after current question
                // This maintains conversational flow
                let insertIndex = min(questionQueue.count, 2)
                questionQueue.insert(question, at: insertIndex)
            } else {
                // Append regular questions to the end
                questionQueue.append(question)
            }
        }
        
        // Update published questions
        self.questions = questionQueue
        
        print("[QuestionRepository] Merged \(newQuestions.count) questions. Queue size: \(questionQueue.count)")
    }
    
    // MARK: - Caching
    
    private func cacheQuestions(_ questions: [InterviewQuestion]) {
        let key = "project_\(projectId)" as NSString
        let questionsArray = questions as NSArray
        questionCache.setObject(questionsArray, forKey: key)
    }
    
    private func getCachedQuestions() -> [InterviewQuestion]? {
        let key = "project_\(projectId)" as NSString
        if let cachedArray = questionCache.object(forKey: key) as? [InterviewQuestion] {
            return cachedArray
        }
        return nil
    }
    
    private func clearCache() {
        questionCache.removeAllObjects()
    }
    
    // MARK: - Cleanup
    
    func getCachedQuestions(for projectId: Int) async -> [InterviewQuestion]? {
        return getCachedQuestions()
    }
    
    func cleanup() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isPolling = false
        clearCache()
        questionQueue.removeAll()
        processedQuestionIds.removeAll()
    }
    
    deinit {
        // Cleanup is handled when the repository is no longer needed
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}

// MARK: - InterviewQuestion Extension

extension InterviewQuestion {
    // Note: id property already exists from Identifiable conformance in InterviewQuestion
    
    var isGenerated: Bool {
        // Questions generated on-the-fly typically have no parent but are follow-ups
        return self.isFollowUp && self.parentQuestionId == nil
    }
    
    var audioPath: String? {
        // Return the Polly audio URL if available
        return self.pollyAudioUrl
    }
    
    var audioUrl: URL? {
        // Convert audio path to URL if available
        if let audioPath = self.audioPath {
            return URL(string: audioPath)
        }
        return nil
    }
    
    static func skeleton() -> InterviewQuestion {
        return InterviewQuestion(
            questionId: 0,
            text: "Loading your first question...",
            order: 0,
            omitted: false,
            skipped: false,
            parentQuestionId: nil,
            isFollowUp: false,
            sectionId: 0,
            sectionTitle: "Getting Started",
            chapterId: 0,
            chapterTitle: "Interview",
            pollyAudioUrl: nil
        )
    }
}