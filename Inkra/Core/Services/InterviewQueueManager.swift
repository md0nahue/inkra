import Foundation
import SwiftUI
import os.log

@MainActor
class InterviewQueueManager: ObservableObject {
    private let logger = Logger(subsystem: "com.inkra.app", category: "InterviewQueue")
    @Published private(set) var fullQueue: [Question] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isFinished: Bool = false
    
    var currentQuestion: Question? {
        guard currentIndex < fullQueue.count else { return nil }
        return fullQueue[currentIndex]
    }
    
    var remainingQuestions: Int {
        return max(0, fullQueue.count - currentIndex)
    }
    
    var completedQuestions: Int {
        return currentIndex
    }
    
    var progress: Double {
        guard !fullQueue.isEmpty else { return 0 }
        return Double(currentIndex) / Double(fullQueue.count)
    }
    
    func initializeQueue(with questions: [Question]) {
        logger.info("✨ Initializing interview queue with \(questions.count) questions")
        self.fullQueue = questions
        self.currentIndex = 0
        self.isFinished = false
    }
    
    func advance() {
        guard currentIndex < fullQueue.count else {
            logger.info("📍 Reached end of queue at index \(self.currentIndex)")
            isFinished = true
            return
        }
        
        currentIndex += 1
        logger.info("➡️ Advanced to question \(self.currentIndex + 1) of \(self.fullQueue.count)")
        
        if currentIndex >= fullQueue.count {
            isFinished = true
            logger.info("✅ Interview queue completed")
        }
    }
    
    func mergeNewQuestions(_ newQuestions: [Question]) {
        guard !newQuestions.isEmpty else { return }
        
        logger.info("✨ Merging \(newQuestions.count) new follow-up questions into the queue")
        
        let insertionIndex = min(currentIndex + 1, fullQueue.count)
        
        fullQueue.insert(contentsOf: newQuestions, at: insertionIndex)
        
        logger.info("✅ New queue count: \(self.fullQueue.count), current index: \(self.currentIndex)")
        
        if isFinished && !newQuestions.isEmpty {
            isFinished = false
            logger.info("🔄 Reopening finished queue with new questions")
        }
    }
    
    func skipCurrentQuestion() {
        logger.info("⏭ Skipping current question at index \(self.currentIndex)")
        advance()
    }
    
    func reset() {
        logger.info("🔄 Resetting interview queue")
        currentIndex = 0
        isFinished = false
    }
    
    func getQuestionsInRange(start: Int, count: Int) -> [Question] {
        let startIndex = max(0, start)
        let endIndex = min(startIndex + count, fullQueue.count)
        
        guard startIndex < endIndex else { return [] }
        
        return Array(fullQueue[startIndex..<endIndex])
    }
    
    func findQuestionIndex(byId questionId: Int) -> Int? {
        return fullQueue.firstIndex { $0.questionId == questionId }
    }
    
    func jumpToQuestion(at index: Int) -> Bool {
        guard index >= 0 && index < fullQueue.count else {
            logger.error("Invalid jump index: \(index) (queue size: \(self.fullQueue.count))")
            return false
        }
        
        currentIndex = index
        isFinished = false
        logger.info("📍 Jumped to question at index \(index)")
        return true
    }
    
    func getUpcomingQuestions(limit: Int = 3) -> [Question] {
        let startIdx = currentIndex + 1
        let endIdx = min(startIdx + limit, fullQueue.count)
        
        guard startIdx < fullQueue.count else { return [] }
        
        return Array(fullQueue[startIdx..<endIdx])
    }
    
    func debugPrintQueue() {
        logger.info("""
            📋 Interview Queue Status:
            - Total questions: \(self.fullQueue.count)
            - Current index: \(self.currentIndex)
            - Current question: \(self.currentQuestion?.text ?? "None")
            - Is finished: \(self.isFinished)
            - Progress: \(Int(self.progress * 100))%
            """)
    }
}

extension InterviewQueueManager {
    func insertFollowUpQuestions(_ questions: [Question], afterQuestionId parentId: Int) {
        guard let parentIndex = findQuestionIndex(byId: parentId) else {
            logger.warning("Parent question \(parentId) not found in queue")
            mergeNewQuestions(questions)
            return
        }
        
        let insertionIndex = min(parentIndex + 1, fullQueue.count)
        
        logger.info("📍 Inserting \(questions.count) follow-ups after question at index \(parentIndex)")
        
        fullQueue.insert(contentsOf: questions, at: insertionIndex)
        
        if isFinished && !questions.isEmpty {
            isFinished = false
        }
    }
    
    func removeQuestion(at index: Int) -> Bool {
        guard index >= 0 && index < fullQueue.count else { return false }
        
        fullQueue.remove(at: index)
        
        if index < currentIndex {
            currentIndex = max(0, currentIndex - 1)
        }
        
        if currentIndex >= fullQueue.count && !fullQueue.isEmpty {
            currentIndex = fullQueue.count - 1
        }
        
        logger.info("🗑 Removed question at index \(index), adjusted current index to \(self.currentIndex)")
        return true
    }
}