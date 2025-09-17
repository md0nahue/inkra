import Foundation

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class TranscriptViewModel: ObservableObject, ErrorHandling {
    @Published var project: Project
    @Published var transcript: Transcript?
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var refreshDate: Date?
    @Published var displayMode: TranscriptDisplayMode = .edited
    @Published var isEditing: Bool = false
    @Published var isSaving: Bool = false
    @Published var editedContent: String = ""
    @Published var questionsWithResponses: [InterviewQuestionWithResponse] = []
    
    enum TranscriptDisplayMode: String, CaseIterable, Identifiable {
        case raw = "Raw"
        case edited = "Edited"
        var id: String { self.rawValue }
    }
    
    private let transcriptService: TranscriptServiceProtocol
    private let projectService: ProjectServiceProtocol
    
    init(project: Project, transcriptService: TranscriptServiceProtocol = TranscriptService(), projectService: ProjectServiceProtocol = ProjectService()) {
        self.project = project
        self.transcriptService = transcriptService
        self.projectService = projectService
    }
    
    var canViewTranscript: Bool {
        // Allow loading transcript view if project has an outline (questions exist)
        // The actual display logic will filter based on whether there are responses
        return project.outline != nil
    }
    
    var isTranscriptReady: Bool {
        transcript?.status == .ready
    }
    
    var isEditedTranscriptReady: Bool {
        transcript?.status == .ready
    }
    
    var isRawStructuredContentReady: Bool {
        guard let status = transcript?.status else { return false }
        return status == .rawReady || status == .editing || status == .ready
    }
    
    var isProcessing: Bool {
        guard let status = transcript?.status else { return project.status == .transcribing }
        return status == .processingRaw || status == .editing || project.status == .transcribing
    }
    
    var currentLoadingText: String {
        guard let status = transcript?.status else { return "Loading transcript..." }
        switch status {
        case .processingRaw:
            return "Transcribing audio segments..."
        case .rawReady:
            return "Raw transcript ready. Initiating AI polishing..."
        case .editing:
            return "AI is polishing your story..."
        case .ready:
            return "Transcript ready!"
        case .failed:
            return "Transcript processing failed."
        }
    }
    
    var hasFailed: Bool {
        transcript?.status == .failed
    }
    
    var hasQuestionsData: Bool {
        !questionsWithResponses.isEmpty
    }
    
    var questionsByChapter: [ChapterQuestionsWithResponses] {
        let grouped = Dictionary(grouping: questionsWithResponses) { question in
            question.chapterTitle
        }
        
        return grouped.map { chapterTitle, questions in
            ChapterQuestionsWithResponses(
                chapterTitle: chapterTitle,
                questions: questions.sorted { $0.order < $1.order }
            )
        }.sorted { $0.chapterTitle < $1.chapterTitle }
    }
    
    var groupedContent: [ContentGroup] {
        guard let transcript = transcript else { return [] }
        
        // Select content based on display mode
        let contentToGroup: [TranscriptContent]
        if displayMode == .edited {
            contentToGroup = transcript.editedContent
        } else {
            contentToGroup = transcript.rawStructuredContent ?? []
        }
        
        var groups: [ContentGroup] = []
        var currentChapter: TranscriptContent?
        var currentSection: TranscriptContent?
        var currentParagraphs: [TranscriptContent] = []
        
        for content in contentToGroup {
            switch content.type {
            case .chapter:
                if let chapter = currentChapter {
                    groups.append(ContentGroup(
                        chapter: chapter,
                        section: currentSection,
                        paragraphs: currentParagraphs
                    ))
                }
                currentChapter = content
                currentSection = nil
                currentParagraphs = []
                
            case .section:
                if let chapter = currentChapter, let section = currentSection {
                    groups.append(ContentGroup(
                        chapter: chapter,
                        section: section,
                        paragraphs: currentParagraphs
                    ))
                }
                currentSection = content
                currentParagraphs = []
                
            case .paragraph:
                currentParagraphs.append(content)
            }
        }
        
        if let chapter = currentChapter {
            groups.append(ContentGroup(
                chapter: chapter,
                section: currentSection,
                paragraphs: currentParagraphs
            ))
        }
        
        return groups
    }
    
    func loadTranscript() async {
        ErrorLogger.shared.logViewAppearance(viewName: "TranscriptView.loadTranscript", additionalData: [
            "projectId": project.id,
            "projectTitle": project.title,
            "projectStatus": project.status.rawValue,
            "canViewTranscript": canViewTranscript,
            "currentTranscript": transcript != nil ? "exists" : "nil"
        ])
        
        guard canViewTranscript else {
            ErrorLogger.shared.logNavigationBlocked(
                reason: "Cannot view transcript - project has no outline",
                from: "TranscriptView"
            )
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        let correlationId = UUID().uuidString
        
        do {
            // First try to load the processed transcript
            ErrorLogger.shared.logNetworkRequest(
                "/api/projects/\(project.id)/transcript",
                responseType: Transcript.self,
                correlationId: correlationId
            )
            
            do {
                let loadedTranscript = try await transcriptService.getTranscript(projectId: project.id)
                transcript = loadedTranscript
                
                // If transcript is ready with content, we can show it
                if loadedTranscript.status == .ready && !loadedTranscript.editedContent.isEmpty {
                    displayMode = .edited
                    isLoading = false
                    return
                } else if isRawStructuredContentReady {
                    displayMode = .raw
                    isLoading = false
                    return
                }
            } catch {
                // Transcript not ready, continue to load Q&A
                print("Transcript not ready, loading Q&A instead: \(error)")
            }
            
            // Load questions with responses as fallback
            ErrorLogger.shared.logNetworkRequest(
                "/api/projects/\(project.id)/available_questions",
                responseType: [InterviewQuestion].self,
                correlationId: correlationId + "-qa"
            )
            
            let response = try await projectService.getQuestionsWithResponses(projectId: project.id)
            questionsWithResponses = response.questions
            
            // Debug: Log sample questions to verify text is present
            for (index, question) in response.questions.prefix(3).enumerated() {
                print("📝 TranscriptView Question \(index + 1): '\(question.text)' (isEmpty: \(question.text.isEmpty))")
            }
            
            ErrorLogger.shared.logUserAction(
                "Questions with responses loaded for transcript view",
                in: "TranscriptView",
                details: [
                    "projectId": project.id,
                    "questionsCount": response.questions.count,
                    "questionsWithResponses": response.questionsWithResponses,
                    "questionsWithTranscriptions": response.questionsWithTranscriptions,
                    "firstQuestionText": response.questions.first?.text ?? "NO TEXT",
                    "correlationId": correlationId + "-qa"
                ]
            )
            
        } catch {
            ErrorLogger.shared.logError(error, context: "TranscriptView.loadTranscript", additionalData: [
                "projectId": project.id,
                "correlationId": correlationId,
                "operation": "loadTranscript"
            ])
            handleError(error)
        }
        
        isLoading = false
    }
    
    func refreshTranscript() async {
        await loadTranscript()
    }
    
    func exportTranscript() -> String {
        guard let transcript = transcript else { return "" }
        
        var exportText = ""
        exportText += "\(project.title)\n"
        if let lastUpdated = transcript.lastUpdated {
            exportText += "Generated on \(lastUpdated.formatted())\n\n"
        }
        
        for group in groupedContent {
            exportText += "\(group.chapter.title ?? "Chapter")\n"
            exportText += String(repeating: "=", count: group.chapter.title?.count ?? 7)
            exportText += "\n\n"
            
            if let section = group.section {
                exportText += "\(section.title ?? "Section")\n"
                exportText += String(repeating: "-", count: section.title?.count ?? 7)
                exportText += "\n\n"
            }
            
            for paragraph in group.paragraphs {
                if let text = paragraph.text {
                    exportText += "\(text)\n\n"
                }
            }
        }
        
        return exportText
    }
    
    // MARK: - Editing Methods
    
    func startEditing() {
        guard let transcript = transcript else { return }
        
        isEditing = true
        
        // Initialize editing content
        if let polishedContent = transcript.polishedContent {
            editedContent = polishedContent
        } else {
            // Fall back to raw content if no polished content available
            var rawText = ""
            for group in groupedContent {
                rawText += "\(group.chapter.title ?? "Chapter")\n\n"
                
                if let section = group.section {
                    rawText += "\(section.title ?? "Section")\n\n"
                }
                
                for paragraph in group.paragraphs {
                    if let text = paragraph.text {
                        rawText += "\(text)\n\n"
                    }
                }
            }
            editedContent = rawText
        }
    }
    
    func cancelEditing() {
        isEditing = false
        editedContent = ""
        errorMessage = ""
        showError = false
    }
    
    func saveEditing() async {
        guard !editedContent.isEmpty else {
            errorMessage = "Content cannot be empty"
            showError = true
            return
        }
        
        isSaving = true
        errorMessage = ""
        
        do {
            let _ = try await transcriptService.updateTranscript(
                projectId: project.id,
                polishedContent: editedContent,
                editedContent: transcript?.editedContent
            )
            
            // Refresh the transcript to get updated data
            await loadTranscript()
            
            // Exit editing mode
            isEditing = false
            editedContent = ""
            
            print("✅ Transcript updated successfully")
            
        } catch {
            handleError(error)
        }
        
        isSaving = false
    }
    
    var canEdit: Bool {
        guard let transcript = transcript else { return false }
        return transcript.status == .ready && !isEditing
    }
    
    var hasUnsavedChanges: Bool {
        guard isEditing, let transcript = transcript else { return false }
        return editedContent != (transcript.polishedContent ?? "")
    }
    
}

struct ContentGroup {
    let chapter: TranscriptContent
    let section: TranscriptContent?
    let paragraphs: [TranscriptContent]
}