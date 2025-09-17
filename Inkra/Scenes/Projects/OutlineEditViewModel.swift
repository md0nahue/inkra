import Foundation

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class OutlineEditViewModel: ObservableObject, ErrorHandling {
    @Published var currentProject: Project
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var expandedSections: Set<Int> = []
    
    private let projectService: ProjectServiceProtocol
    private var originalOutline: Outline?
    private var pendingChanges: [Int: Bool] = [:]
    
    init(project: Project, projectService: ProjectServiceProtocol = ProjectService()) {
        self.currentProject = project
        self.projectService = projectService
        self.originalOutline = project.outline
    }
    
    var hasChanges: Bool {
        !pendingChanges.isEmpty
    }
    
    func isChapterOmitted(_ chapterId: Int) -> Bool {
        if let pendingChange = pendingChanges[chapterId] {
            return pendingChange
        }
        
        return currentProject.outline?.chapters.first { $0.id == chapterId }?.omitted ?? false
    }
    
    func isSectionOmitted(_ sectionId: Int) -> Bool {
        if let pendingChange = pendingChanges[sectionId] {
            return pendingChange
        }
        
        guard let outline = currentProject.outline else { return false }
        
        for chapter in outline.chapters {
            if let section = chapter.sections.first(where: { $0.id == sectionId }) {
                // If parent chapter is omitted, section is also considered omitted
                if isChapterOmittedDirect(chapter.id) {
                    return true
                }
                return section.omitted
            }
        }
        
        return false
    }
    
    func isQuestionOmitted(_ questionId: Int) -> Bool {
        if let pendingChange = pendingChanges[questionId] {
            return pendingChange
        }
        
        guard let outline = currentProject.outline else { return false }
        
        for chapter in outline.chapters {
            for section in chapter.sections {
                if let question = section.questions.first(where: { $0.id == questionId }) {
                    // If parent chapter or section is omitted, question is also considered omitted
                    if isChapterOmittedDirect(chapter.id) || isSectionOmittedDirect(section.id) {
                        return true
                    }
                    return question.omitted
                }
            }
        }
        
        return false
    }
    
    private func isChapterOmittedDirect(_ chapterId: Int) -> Bool {
        if let pendingChange = pendingChanges[chapterId] {
            return pendingChange
        }
        return currentProject.outline?.chapters.first { $0.id == chapterId }?.omitted ?? false
    }
    
    private func isSectionOmittedDirect(_ sectionId: Int) -> Bool {
        if let pendingChange = pendingChanges[sectionId] {
            return pendingChange
        }
        
        guard let outline = currentProject.outline else { return false }
        
        for chapter in outline.chapters {
            if let section = chapter.sections.first(where: { $0.id == sectionId }) {
                return section.omitted
            }
        }
        
        return false
    }
    
    func isSectionExpanded(_ sectionId: Int) -> Bool {
        expandedSections.contains(sectionId)
    }
    
    func toggleChapter(_ chapterId: Int) {
        let currentValue = isChapterOmitted(chapterId)
        let newValue = !currentValue
        pendingChanges[chapterId] = newValue
        
        // Cascade omission to all sections and questions in this chapter
        if let chapter = currentProject.outline?.chapters.first(where: { $0.id == chapterId }) {
            for section in chapter.sections {
                pendingChanges[section.id] = newValue
                for question in section.questions {
                    pendingChanges[question.id] = newValue
                }
            }
        }
        
        // Force UI update
        objectWillChange.send()
    }
    
    func toggleSection(_ sectionId: Int) {
        let currentValue = isSectionOmitted(sectionId)
        let newValue = !currentValue
        pendingChanges[sectionId] = newValue
        
        // Cascade omission to all questions in this section
        if let section = findSection(sectionId) {
            for question in section.questions {
                pendingChanges[question.id] = newValue
            }
        }
        
        // Force UI update
        objectWillChange.send()
    }
    
    func toggleQuestion(_ questionId: Int) {
        let currentValue = isQuestionOmitted(questionId)
        pendingChanges[questionId] = !currentValue
        
        // Force UI update
        objectWillChange.send()
    }
    
    func toggleSectionExpansion(_ sectionId: Int) {
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
    }
    
    func saveChanges() async {
        guard hasChanges else { return }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let updates = buildOutlineUpdates()
            let _ = try await projectService.updateOutline(projectId: currentProject.id, updates: updates)
            
            applyChangesToCurrentProject()
            pendingChanges.removeAll()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    private func buildOutlineUpdates() -> [OutlineUpdate] {
        var updates: [OutlineUpdate] = []
        
        for (id, omitted) in pendingChanges {
            if isChapterUpdate(id) {
                updates.append(OutlineUpdate(chapterId: id, sectionId: nil, questionId: nil, omitted: omitted))
            } else if isSectionUpdate(id) {
                updates.append(OutlineUpdate(chapterId: nil, sectionId: id, questionId: nil, omitted: omitted))
            } else {
                // Question update
                updates.append(OutlineUpdate(chapterId: nil, sectionId: nil, questionId: id, omitted: omitted))
            }
        }
        
        return updates
    }
    
    private func findSection(_ sectionId: Int) -> Section? {
        guard let outline = currentProject.outline else { return nil }
        for chapter in outline.chapters {
            if let section = chapter.sections.first(where: { $0.id == sectionId }) {
                return section
            }
        }
        return nil
    }
    
    private func isChapterUpdate(_ id: Int) -> Bool {
        guard let outline = currentProject.outline else { return false }
        return outline.chapters.contains { $0.id == id }
    }
    
    private func isSectionUpdate(_ id: Int) -> Bool {
        guard let outline = currentProject.outline else { return false }
        for chapter in outline.chapters {
            if chapter.sections.contains(where: { $0.id == id }) {
                return true
            }
        }
        return false
    }
    
    private func applyChangesToCurrentProject() {
        guard var outline = currentProject.outline else { return }
        
        var updatedChapters = outline.chapters
        
        for (id, omitted) in pendingChanges {
            if let chapterIndex = updatedChapters.firstIndex(where: { $0.id == id }) {
                // Update chapter
                updatedChapters[chapterIndex].omitted = omitted
            } else {
                // Check if it's a section or question update
                for chapterIndex in updatedChapters.indices {
                    if let sectionIndex = updatedChapters[chapterIndex].sections.firstIndex(where: { $0.id == id }) {
                        // Update section
                        var updatedSections = updatedChapters[chapterIndex].sections
                        updatedSections[sectionIndex].omitted = omitted
                        updatedChapters[chapterIndex] = Chapter(
                            chapterId: updatedChapters[chapterIndex].chapterId,
                            title: updatedChapters[chapterIndex].title,
                            order: updatedChapters[chapterIndex].order,
                            omitted: updatedChapters[chapterIndex].omitted,
                            sections: updatedSections
                        )
                        break
                    } else {
                        // Check for question update
                        for sectionIndex in updatedChapters[chapterIndex].sections.indices {
                            if let questionIndex = updatedChapters[chapterIndex].sections[sectionIndex].questions.firstIndex(where: { $0.id == id }) {
                                // Update question
                                var updatedSections = updatedChapters[chapterIndex].sections
                                var updatedQuestions = updatedSections[sectionIndex].questions
                                let question = updatedQuestions[questionIndex]
                                updatedQuestions[questionIndex] = Question(
                                    questionId: question.questionId,
                                    text: question.text,
                                    order: question.order,
                                    omitted: omitted,
                                    parentQuestionId: question.parentQuestionId,
                                    isFollowUp: question.isFollowUp
                                )
                                updatedSections[sectionIndex] = Section(
                                    sectionId: updatedSections[sectionIndex].sectionId,
                                    title: updatedSections[sectionIndex].title,
                                    order: updatedSections[sectionIndex].order,
                                    omitted: updatedSections[sectionIndex].omitted,
                                    questions: updatedQuestions
                                )
                                updatedChapters[chapterIndex] = Chapter(
                                    chapterId: updatedChapters[chapterIndex].chapterId,
                                    title: updatedChapters[chapterIndex].title,
                                    order: updatedChapters[chapterIndex].order,
                                    omitted: updatedChapters[chapterIndex].omitted,
                                    sections: updatedSections
                                )
                                break
                            }
                        }
                    }
                }
            }
        }
        
        outline = Outline(status: outline.status, chapters: updatedChapters)
        currentProject = Project(
            id: currentProject.id,
            title: currentProject.title,
            createdAt: currentProject.createdAt,
            lastModifiedAt: currentProject.lastModifiedAt,
            lastAccessedAt: currentProject.lastAccessedAt,
            preset: currentProject.preset,
            outline: outline,
            isSpeechInterview: currentProject.isSpeechInterview,
            presetId: currentProject.presetId,
            isOffline: currentProject.isOffline
        )
    }
    
}