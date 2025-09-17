import Foundation
import Combine

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class InterviewQuestionService: ObservableObject {
    @Published var currentQuestion: Question?
    @Published var dynamicQuestionQueue: [Question] = []
    @Published var interviewQuestions: [InterviewQuestion] = []
    @Published var pollyAudioUrls: [Int: String] = [:]
    @Published var skippedQuestionIds: Set<Int> = []
    @Published var isLoading: Bool = false
    
    private var currentQuestionIndex: Int = 0
    
    private let project: Project
    private let projectService: ProjectServiceProtocol
    private let networkService: NetworkConnectivityService
    
    // Network concurrency throttling
    private let downloadSemaphore = DispatchSemaphore(value: 4) // Max 4 concurrent downloads
    private let maxConcurrentDownloads = 4
    
    init(project: Project, 
         projectService: ProjectServiceProtocol = ProjectService(), 
         networkService: NetworkConnectivityService = NetworkConnectivityService.shared) {
        self.project = project
        self.projectService = projectService
        self.networkService = networkService
    }
    
    // MARK: - Throttled Network Operations
    
    private func downloadAudioWithThrottling(questionId: Int, url: String, priority: TaskPriority = .userInitiated) async throws {
        // Use async semaphore pattern instead of blocking wait
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task(priority: priority) {
                // Acquire semaphore asynchronously
                await withUnsafeContinuation { semaphoreContinuation in
                    DispatchQueue.global().async {
                        self.downloadSemaphore.wait()
                        semaphoreContinuation.resume()
                    }
                }
                defer { self.downloadSemaphore.signal() }
                
                do {
                    try await AudioCacheService.shared.downloadPollyAudio(for: questionId, from: url, projectId: project.id)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func downloadMultipleAudioWithThrottling(_ audioItems: [(questionId: Int, url: String)]) async {
        await withTaskGroup(of: Void.self) { group in
            for (questionId, url) in audioItems {
                group.addTask(priority: .userInitiated) {
                    do {
                        try await self.downloadAudioWithThrottling(questionId: questionId, url: url)
                        await MainActor.run {
                            print("✅📋 Throttled download complete: question \(questionId)")
                        }
                    } catch {
                        await MainActor.run {
                            print("⚠️📋 Throttled download failed for question \(questionId): \(error)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Question Loading
    
    func loadAvailableQuestions() async throws {
        guard !(project.isOffline ?? false) && networkService.isConnected else {
            await setupOfflineFallback()
            return
        }
        
        print("\n📂🚀 LOADING AVAILABLE QUESTIONS")
        print("   🆔 Project ID: \(project.id)")
        print("   📝 Project: \"\(project.title)\"")
        
        isLoading = true
        let response = try await projectService.getAvailableQuestions(projectId: project.id)
        
        // Store the full interview questions
        self.interviewQuestions = response.questions
        
        // CACHE SAFETY: Clear pollyAudioUrls before repopulating to prevent stale mappings
        print("   🧽 Clearing old audio URL mappings (had \(self.pollyAudioUrls.count) entries)")
        self.pollyAudioUrls = [:]
        var firstQuestionUrl: (Int, String)?
        
        print("\n🎵🔍 AUDIO URL MAPPING DEBUG - loadAvailableQuestions")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        for (index, question) in response.questions.enumerated() {
            if let pollyUrl = question.pollyAudioUrl {
                self.pollyAudioUrls[question.id] = pollyUrl
                print("📌 Question \(question.id): \"\(question.text.prefix(50))...\"")
                print("   🔗 Audio URL: \(pollyUrl)")
                // Capture the first question's audio URL for priority caching
                if index == 0 {
                    firstQuestionUrl = (question.id, pollyUrl)
                    print("   ⭐ FIRST QUESTION - Priority caching")
                }
            } else {
                print("⚠️ Question \(question.id) has NO audio URL: \"\(question.text.prefix(50))...\"")
            }
        }
        print("✅ Total audio URLs mapped: \(self.pollyAudioUrls.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        // Convert InterviewQuestion to Question for backwards compatibility
        self.dynamicQuestionQueue = response.questions.map { $0.asQuestion }
        
        // Set current question to first unanswered
        updateCurrentQuestion()
        
        print("   ✅ Questions loaded: \(response.questions.count) total, \(self.pollyAudioUrls.count) with audio")
        
        // AGGRESSIVE BACKGROUND PRELOADING: Start downloads immediately without blocking
        Task.detached(priority: .userInitiated) {
            // STEP 1: Download all available audio files in background
            let allAudioUrls = response.questions.compactMap { question -> (Int, String)? in
                guard let pollyUrl = question.pollyAudioUrl else { return nil }
                return (question.id, pollyUrl)
            }
            
            print("🚀⚡ BACKGROUND PRELOAD: Starting \(allAudioUrls.count) audio downloads")
            
            // Download first question with highest priority (blocks until complete)
            if let (questionId, url) = firstQuestionUrl {
                print("🎵📥 Priority download: First question (ID: \(questionId))")
                do {
                    try await AudioCacheService.shared.downloadPollyAudio(for: questionId, from: url, projectId: self.project.id)
                    print("✅💾 First question cached to disk")
                    
                    // V1: Audio preloading disabled for V1 simplicity
                    // await MainActor.run {
                    //     NativeVoiceService.shared.preloadAudio(url: url, for: questionId)
                    //     print("⚡ First question preloaded to memory")
                    // }
                } catch {
                    print("⚠️ Priority download failed: \(error)")
                }
            }
            
            // Download remaining questions with throttling
            if allAudioUrls.count > 1 {
                let remainingItems = Array(allAudioUrls.dropFirst()).map { (questionId: $0.0, url: $0.1) }
                await self.downloadMultipleAudioWithThrottling(remainingItems)
                
                // Memory preload next 2 questions for smooth flow
                for (questionId, url) in remainingItems.prefix(2) {
                    await MainActor.run {
                        NativeVoiceService.shared.preloadAudio(url: url, for: questionId)
                        print("⚡📋 Background preloaded question \(questionId) to memory")
                    }
                }
            }
            
            print("✅🚀 BACKGROUND PRELOAD COMPLETE: All audio downloads initiated")
        }
        
        isLoading = false
    }
    
    func loadAvailableQuestionsWithPriority() async throws {
        let response = try await projectService.getAvailableQuestions(projectId: project.id)
        
        let previousQueueCount = self.dynamicQuestionQueue.count
        
        // Store the full interview questions
        self.interviewQuestions = response.questions
        
        // Extract polly audio URLs if present
        // Server now only returns questions with completed audio for speech interviews
        print("\n🎵🔍 AUDIO URL MAPPING DEBUG - loadAvailableQuestionsWithPriority/checkForFollowUpQuestions")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        self.pollyAudioUrls = [:]
        for question in response.questions {
            if let pollyUrl = question.pollyAudioUrl {
                self.pollyAudioUrls[question.id] = pollyUrl
                print("📌 Question \(question.id): \"\(question.text.prefix(50))...\"")
                print("   🔗 Audio URL: \(pollyUrl)")
            } else {
                print("⚠️ Question \(question.id) has NO audio URL: \"\(question.text.prefix(50))...\"")
            }
        }
        print("✅ Total audio URLs mapped: \(self.pollyAudioUrls.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        // Update dynamic queue
        self.dynamicQuestionQueue = response.questions.map { $0.asQuestion }
        
        let hasNewQuestions = dynamicQuestionQueue.count > previousQueueCount
        if hasNewQuestions {
            print("✨ Priority load found \(dynamicQuestionQueue.count - previousQueueCount) new questions")
            updateCurrentQuestion()
        }
    }
    
    func checkForFollowUpQuestions(for parentQuestionId: Int) async throws {
        let response = try await projectService.getAvailableQuestions(projectId: project.id)
        
        let oldQueueCount = self.dynamicQuestionQueue.count
        
        // Update the question queue with new data
        self.interviewQuestions = response.questions
        
        // Extract polly audio URLs if present
        // Server now only returns questions with completed audio for speech interviews
        print("\n🎵🔍 AUDIO URL MAPPING DEBUG - loadAvailableQuestionsWithPriority/checkForFollowUpQuestions")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        self.pollyAudioUrls = [:]
        for question in response.questions {
            if let pollyUrl = question.pollyAudioUrl {
                self.pollyAudioUrls[question.id] = pollyUrl
                print("📌 Question \(question.id): \"\(question.text.prefix(50))...\"")
                print("   🔗 Audio URL: \(pollyUrl)")
            } else {
                print("⚠️ Question \(question.id) has NO audio URL: \"\(question.text.prefix(50))...\"")
            }
        }
        print("✅ Total audio URLs mapped: \(self.pollyAudioUrls.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        // Update the dynamic queue
        self.dynamicQuestionQueue = response.questions.map { $0.asQuestion }
        
        if response.questions.count > oldQueueCount {
            print("✨ New follow-up questions have arrived! Queue grew from \(oldQueueCount) to \(response.questions.count)")
            print("🎵 Server-side filtering ensures all questions have completed audio for speech interviews")
            
            // THROTTLED PRELOAD: Download new follow-up questions with concurrency limits
            Task.detached(priority: .userInitiated) {
                let newQuestions = Array(response.questions.dropFirst(oldQueueCount))
                print("🚀⚡ THROTTLED PRELOAD: Starting downloads for \(newQuestions.count) new follow-up questions")
                
                let audioItems = newQuestions.compactMap { question -> (questionId: Int, url: String)? in
                    guard let pollyUrl = question.pollyAudioUrl else { return nil }
                    return (questionId: question.id, url: pollyUrl)
                }
                
                await self.downloadMultipleAudioWithThrottling(audioItems)
                
                // V1: Audio preloading disabled for V1 simplicity
                // for (questionId, url) in audioItems.prefix(2) {
                //     await MainActor.run {
                //         NativeVoiceService.shared.preloadAudio(url: url, for: questionId)
                //         print("⚡📋 Follow-up preloaded to memory: question \(questionId)")
                //     }
                // }
                
                print("✅🚀 THROTTLED FOLLOWUP PRELOAD COMPLETE")
            }
        }
    }
    
    private func setupOfflineFallback() async {
        print("📱 Setting up offline fallback - using project outline questions")
        
        // Use questions from the project outline as fallback
        setupOfflineQuestions()
    }
    
    func setupOfflineQuestions() {
        self.dynamicQuestionQueue = allQuestionsFromOutline
        updateCurrentQuestion()
        self.isLoading = false
        
        print("✅ Offline fallback ready with \(self.dynamicQuestionQueue.count) questions")
    }
    
    // MARK: - Question Navigation
    
    func findNextUnansweredQuestion(after currentIndex: Int, recordedSegments: [Int: AudioSegmentInfo]) -> Int? {
        print("\n🔍🔍🔍 FINDING NEXT UNANSWERED QUESTION 🔍🔍🔍")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📍 Starting search after index: \(currentIndex)")
        print("📊 Total questions in queue: \(dynamicQuestionQueue.count)")
        print("📝 Recorded segments: \(recordedSegments.keys.sorted())")
        print("🚫 Skipped questions: \(skippedQuestionIds.sorted())")
        
        // Find the first unanswered question after current position
        print("🔍 Searching forward from index \(currentIndex + 1) to \(dynamicQuestionQueue.count - 1)")
        for i in (currentIndex + 1)..<dynamicQuestionQueue.count {
            let question = dynamicQuestionQueue[i]
            let hasRecording = recordedSegments[question.id] != nil
            let isSkipped = isQuestionSkipped(question.id)
            print("   Index \(i): Q\(question.id) - recorded=\(hasRecording), skipped=\(isSkipped)")
            
            if !hasRecording && !isSkipped {
                print("✅ Found next unanswered question at index \(i): Q\(question.id)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                return i
            }
        }
        
        // If no unanswered questions found after current position, check from beginning
        print("🔍 No questions found forward, searching from beginning (0 to \(currentIndex - 1))")
        for i in 0..<currentIndex {
            let question = dynamicQuestionQueue[i]
            let hasRecording = recordedSegments[question.id] != nil
            let isSkipped = isQuestionSkipped(question.id)
            print("   Index \(i): Q\(question.id) - recorded=\(hasRecording), skipped=\(isSkipped)")
            
            if !hasRecording && !isSkipped {
                print("✅ Found next unanswered question at index \(i): Q\(question.id) (wrapped around)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                return i
            }
        }
        
        print("❌ No unanswered questions found in entire queue")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        return nil
    }
    
    func getCurrentQuestionIndex() -> Int {
        return currentQuestionIndex
    }
    
    func setCurrentQuestionIndex(_ index: Int) {
        print("\n📍📍📍 SET CURRENT QUESTION INDEX 📍📍📍")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 Requested index: \(index)")
        print("📊 Queue size: \(dynamicQuestionQueue.count)")
        print("📊 Previous index: \(currentQuestionIndex)")
        
        guard index >= 0 && index < dynamicQuestionQueue.count else {
            print("❌ Index \(index) is out of bounds (0..<\(dynamicQuestionQueue.count))")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            return
        }
        
        currentQuestionIndex = index
        let newQuestion = dynamicQuestionQueue[index]
        print("✅ Updated current question index to \(index)")
        let safeText = newQuestion.text.isEmpty ? "[EMPTY]" : String(newQuestion.text.prefix(min(50, newQuestion.text.count)))
        print("📝 New current question: Q\(newQuestion.id) - '\(safeText)...'")
        
        updateCurrentQuestion()
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    private func updateCurrentQuestion() {
        print("🔄 updateCurrentQuestion called - index: \(currentQuestionIndex), queue size: \(dynamicQuestionQueue.count)")
        
        guard currentQuestionIndex < dynamicQuestionQueue.count else {
            print("❌ Current index \(currentQuestionIndex) >= queue size \(dynamicQuestionQueue.count), setting currentQuestion to nil")
            currentQuestion = nil
            return
        }
        
        let newQuestion = dynamicQuestionQueue[currentQuestionIndex]
        currentQuestion = newQuestion
        let safeText = newQuestion.text.isEmpty ? "[EMPTY]" : String(newQuestion.text.prefix(min(50, newQuestion.text.count)))
        print("✅ Current question updated to: Q\(newQuestion.id) - '\(safeText)...'")
    }
    
    // MARK: - Question Management
    
    func skipQuestion(_ questionId: Int) async throws {
        skippedQuestionIds.insert(questionId)
        
        // Send skip notification to the server
        try await projectService.skipQuestion(projectId: project.id, questionId: questionId)
    }
    
    func isQuestionSkipped(_ questionId: Int) -> Bool {
        skippedQuestionIds.contains(questionId)
    }
    
    // MARK: - Helper Properties
    
    var allQuestionsFromOutline: [Question] {
        guard let outline = project.outline else { return [] }
        
        var questions: [Question] = []
        for chapter in outline.chapters {
            if !chapter.omitted {
                for section in chapter.sections {
                    if !section.omitted {
                        for question in section.questions {
                            if !question.omitted {
                                questions.append(question)
                            }
                        }
                    }
                }
            }
        }
        
        return questions.sorted { $0.order < $1.order }
    }
    
    var totalQuestions: Int {
        dynamicQuestionQueue.count
    }
    
    func unansweredQuestions(recordedSegments: [Int: AudioSegmentInfo]) -> Int {
        dynamicQuestionQueue.filter { question in
            recordedSegments[question.id] == nil && !isQuestionSkipped(question.id)
        }.count
    }
    
    func hasUnansweredQuestions(recordedSegments: [Int: AudioSegmentInfo]) -> Bool {
        for question in dynamicQuestionQueue {
            if recordedSegments[question.id] == nil && !isQuestionSkipped(question.id) {
                return true
            }
        }
        return false
    }
    
    func getQuestionDisplayNumber(for question: Question) -> String {
        guard let questionIndex = dynamicQuestionQueue.firstIndex(where: { $0.id == question.id }) else {
            return "?"
        }
        
        // Base questions are numbered sequentially (1, 2, 3...)
        let mainQuestionsBeforeAndIncluding = dynamicQuestionQueue[...questionIndex].filter { !$0.isFollowUp }
        let mainNumber = mainQuestionsBeforeAndIncluding.count
        
        if !question.isFollowUp {
            return "\(mainNumber)"
        }
        
        // Follow-up questions are numbered like "3.1, 3.2..."
        guard let parentId = question.parentQuestionId else {
            return "\(mainNumber).?"
        }
        
        guard let parentIndex = dynamicQuestionQueue.firstIndex(where: { $0.id == parentId }) else {
            return "\(mainNumber).?"
        }

        // The main number for a follow-up is its parent's main number
        let parentMainNumber = dynamicQuestionQueue[...parentIndex].filter { !$0.isFollowUp }.count
        
        // The sub-number is the count of follow-ups for that parent, up to this point
        let followUpNumber = dynamicQuestionQueue[...questionIndex]
            .filter { $0.isFollowUp && $0.parentQuestionId == parentId }
            .count
            
        return "\(parentMainNumber).\(followUpNumber)"
    }
}