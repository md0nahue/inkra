import SwiftUI

enum QuestionFilter: String, CaseIterable {
    case answered = "Answered"
    case all = "All Questions"
    case unanswered = "Unanswered"
    
    var description: String {
        return self.rawValue
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct QuestionsAndAnswersView: View {
    let project: Project
    @StateObject private var viewModel: QuestionsAndAnswersViewModel
    @State private var selectedFilter: QuestionFilter = .answered
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: QuestionsAndAnswersViewModel(project: project))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.questions.isEmpty {
                noDataView
            } else {
                contentView
            }
        }
        .navigationTitle("Questions & Answers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadQuestions()
        }
        .refreshable {
            await viewModel.loadQuestions()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading questions...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Questions Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Questions will appear here once your interview outline is generated.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // Filter controls
            filterSection
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Summary section
                    if viewModel.questions.count > 0 {
                        responsesSummarySection
                            .padding(.horizontal)
                    }
                    
                    ForEach(Array(filteredQuestionsByChapter.enumerated()), id: \.offset) { index, chapter in
                        chapterSection(chapter)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Show:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(QuestionFilter.allCases, id: \.self) { filter in
                        Text(filter.description)
                            .tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
            }
            
            // Filter summary
            if !viewModel.questions.isEmpty {
                HStack {
                    Text(filterSummaryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    private var filterSummaryText: String {
        let filteredCount = filteredQuestions.count
        let totalCount = viewModel.questions.count
        
        switch selectedFilter {
        case .answered:
            return "\(filteredCount) of \(totalCount) questions have answers"
        case .all:
            return "Showing all \(totalCount) questions"
        case .unanswered:
            return "\(filteredCount) of \(totalCount) questions are unanswered"
        }
    }
    
    private var filteredQuestions: [InterviewQuestionWithResponse] {
        switch selectedFilter {
        case .answered:
            return viewModel.questions.filter { question in
                if let response = question.transcribedResponse, !response.isEmpty {
                    return true
                }
                return question.hasResponse
            }
        case .all:
            return viewModel.questions
        case .unanswered:
            return viewModel.questions.filter { question in
                let hasTranscribedResponse = question.transcribedResponse?.isEmpty == false
                return !question.hasResponse && !hasTranscribedResponse
            }
        }
    }
    
    private var filteredQuestionsByChapter: [ChapterQuestionsWithResponses] {
        let grouped = Dictionary(grouping: filteredQuestions) { question in
            question.chapterTitle
        }
        
        return grouped.map { chapterTitle, questions in
            ChapterQuestionsWithResponses(
                chapterTitle: chapterTitle,
                questions: questions.sorted { $0.order < $1.order }
            )
        }.sorted { $0.chapterTitle < $1.chapterTitle }
    }
    
    private var responsesSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interview Summary")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.questions.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Total Questions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.questionsWithResponses)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Answered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.questionsWithTranscriptions)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Transcribed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Progress bar
            if viewModel.questions.count > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Completion: \(Int(Double(viewModel.questionsWithTranscriptions) / Double(viewModel.questions.count) * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    ProgressView(value: Double(viewModel.questionsWithTranscriptions), total: Double(viewModel.questions.count))
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func chapterSection(_ chapter: ChapterQuestionsWithResponses) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chapter header
            Text(chapter.chapterTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Questions in this chapter
            ForEach(Array(chapter.questions.enumerated()), id: \.offset) { index, question in
                questionRow(question, number: index + 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
    
    private func questionRow(_ question: InterviewQuestionWithResponse, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 20, alignment: .leading)
                
                Text(question.text)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            
            // Show actual answer if available, otherwise show status
            HStack(alignment: .top, spacing: 8) {
                Text("A.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 20, alignment: .leading)
                
                if let response = question.transcribedResponse, !response.isEmpty {
                    Text(response)
                        .font(.body)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                } else if question.hasResponse {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio recorded")
                            .font(.body)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        
                        if let duration = question.responseDuration {
                            Text("Duration: \(Int(duration))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let status = question.responseStatus {
                            Text("Status: \(status)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show friendly message when transcription is empty/failed
                        if question.responseStatus == "transcribed" && (question.transcribedResponse?.isEmpty ?? true) {
                            Text("We couldn't hear you say anything")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .italic()
                        }
                    }
                } else {
                    Text("No response recorded")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            if question.isFollowUp {
                Text("Follow-up Question")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class QuestionsAndAnswersViewModel: ObservableObject, ErrorHandling {
    @Published var project: Project
    @Published var questions: [InterviewQuestionWithResponse] = []
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var questionsWithResponses: Int = 0
    @Published var questionsWithTranscriptions: Int = 0
    
    private let projectService: ProjectServiceProtocol
    
    init(project: Project, projectService: ProjectServiceProtocol = ProjectService()) {
        self.project = project
        self.projectService = projectService
    }
    
    var questionsByChapter: [ChapterQuestionsWithResponses] {
        // Group questions by chapter
        let grouped = Dictionary(grouping: questions) { question in
            question.chapterTitle
        }
        
        return grouped.map { chapterTitle, questions in
            ChapterQuestionsWithResponses(
                chapterTitle: chapterTitle,
                questions: questions.sorted { $0.order < $1.order }
            )
        }.sorted { $0.chapterTitle < $1.chapterTitle }
    }
    
    func loadQuestions() async {
        ErrorLogger.shared.logViewAppearance(viewName: "QuestionsAndAnswersView.loadQuestions", additionalData: [
            "projectId": project.id,
            "projectTitle": project.title,
            "projectStatus": project.status.rawValue,
            "hasOutline": project.outline != nil,
            "currentQuestionsCount": questions.count
        ])
        
        ErrorLogger.shared.logStateChange(
            in: "QuestionsAndAnswersView",
            from: questions.isEmpty ? "empty" : "hasData",
            to: "loading",
            context: ["projectId": project.id, "existingQuestions": questions.count]
        )
        
        isLoading = true
        errorMessage = ""
        
        let correlationId = UUID().uuidString
        ErrorLogger.shared.logNetworkRequest(
            "/api/projects/\(project.id)/available_questions",
            responseType: [InterviewQuestion].self,
            correlationId: correlationId
        )
        
        do {
            ErrorLogger.shared.logUserAction(
                "Fetching available questions",
                in: "QuestionsAndAnswersView",
                details: [
                    "projectId": project.id,
                    "projectTitle": project.title,
                    "correlationId": correlationId
                ]
            )
            
            // Use the ProjectService to get questions with their responses
            let response = try await projectService.getQuestionsWithResponses(projectId: project.id)
            
            ErrorLogger.shared.logUserAction(
                "Questions with responses loaded successfully",
                in: "QuestionsAndAnswersView", 
                details: [
                    "projectId": project.id,
                    "questionsCount": response.questions.count,
                    "hasQuestions": !response.questions.isEmpty,
                    "chapters": Set(response.questions.map { $0.chapterTitle }).count,
                    "questionsWithResponses": response.questionsWithResponses,
                    "questionsWithTranscriptions": response.questionsWithTranscriptions,
                    "firstQuestion": response.questions.first?.text ?? "none",
                    "correlationId": correlationId
                ]
            )
            
            // Log detailed question structure for debugging
            if !response.questions.isEmpty {
                for (index, question) in response.questions.prefix(3).enumerated() {
                    ErrorLogger.shared.logUserAction(
                        "Question \(index + 1) details",
                        in: "QuestionsAndAnswersView",
                        details: [
                            "id": question.id,
                            "text": question.text,
                            "chapterTitle": question.chapterTitle,
                            "order": question.order,
                            "isFollowUp": question.isFollowUp
                        ]
                    )
                }
            } else {
                ErrorLogger.shared.logUnexpectedState(
                    "No questions returned from API",
                    in: "QuestionsAndAnswersView",
                    expectedState: "questions array with content",
                    actualState: "empty array",
                    context: [
                        "projectId": project.id,
                        "hasOutline": project.outline != nil
                    ]
                )
            }
            
            questions = response.questions
            questionsWithResponses = response.questionsWithResponses
            questionsWithTranscriptions = response.questionsWithTranscriptions
            
            ErrorLogger.shared.logStateChange(
                in: "QuestionsAndAnswersView",
                from: "loading",
                to: questions.isEmpty ? "empty" : "loaded",
                context: ["questionsCount": questions.count]
            )
        } catch {
            ErrorLogger.shared.logError(error, context: "QuestionsAndAnswersView.loadQuestions", additionalData: [
                "projectId": project.id,
                "correlationId": correlationId,
                "operation": "loadQuestions"
            ])
            ErrorLogger.shared.logDataReadingError(error, operation: "QuestionsAndAnswersView.loadQuestions", additionalContext: [
                "projectId": project.id,
                "projectTitle": project.title,
                "projectStatus": project.status.rawValue,
                "hasOutline": project.outline != nil
            ])
            ErrorLogger.shared.logCriticalBugDetected(
                "Failed to load questions - likely API response structure issue",
                in: "QuestionsAndAnswersView",
                recoveryAction: "Check API response structure matches expected model",
                stackTrace: Thread.callStackSymbols
            )
            handleError(error)
        }
        
        isLoading = false
        ErrorLogger.shared.logStateChange(
            in: "QuestionsAndAnswersView",
            from: "loading",
            to: questions.isEmpty ? "failed-empty" : "loaded",
            context: ["finalQuestionsCount": questions.count, "hasError": !errorMessage.isEmpty]
        )
    }
}

struct ChapterQuestionsWithResponses {
    let chapterTitle: String
    let questions: [InterviewQuestionWithResponse]
}

#Preview {
    NavigationView {
        QuestionsAndAnswersView(project: Project(
            id: 1,
            title: "Test Project",
            createdAt: Date(),
            lastModifiedAt: Date(),
            lastAccessedAt: nil,
            preset: nil,
            outline: nil,
            isSpeechInterview: false,
            presetId: nil,
            isOffline: nil
        ))
    }
}