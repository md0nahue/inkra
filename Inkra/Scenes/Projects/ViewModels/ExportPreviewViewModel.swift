import Foundation

@available(iOS 15.0, macOS 11.0, *)
@MainActor
class ExportPreviewViewModel: ObservableObject {
    @Published var previewData: ExportPreviewData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let project: Project
    private let exportService: ExportServiceProtocol
    
    init(project: Project, exportService: ExportServiceProtocol = ExportService()) {
        self.project = project
        self.exportService = exportService
    }
    
    func loadPreviewData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use the existing export preview endpoint to get structured data
            let response = try await exportService.getExportPreview(projectId: project.id)
            previewData = mapToPreviewData(response)
        } catch {
            errorMessage = "Failed to load preview data: \(error.localizedDescription)"
            previewData = nil
        }
        
        isLoading = false
    }
    
    private func mapToPreviewData(_ response: ExportPreviewResponse) -> ExportPreviewData {
        let projectInfo = ProjectInfo(
            title: response.project.title,
            topic: response.project.topic,
            createdAt: response.project.createdAt,
            status: response.project.status
        )
        
        let chapters = response.outline.map { chapterData in
            let sections = chapterData.sections.map { sectionData in
                let questions = sectionData.questions.map { questionData in
                    let audioSegments = questionData.audioSegments.map { segmentData in
                        AudioSegmentPreview(
                            id: segmentData.id,
                            transcriptionText: segmentData.transcriptionText,
                            durationSeconds: segmentData.durationSeconds
                        )
                    }
                    
                    return QuestionPreview(
                        questionId: questionData.questionId,
                        text: questionData.text,
                        order: questionData.order,
                        omitted: questionData.omitted,
                        audioSegments: audioSegments
                    )
                }
                
                return SectionPreview(
                    title: sectionData.title,
                    order: sectionData.order,
                    omitted: sectionData.omitted,
                    questions: questions
                )
            }
            
            return ChapterPreview(
                title: chapterData.title,
                order: chapterData.order,
                omitted: chapterData.omitted,
                sections: sections
            )
        }
        
        let statistics = StatisticsPreview(
            totalQuestions: response.statistics.totalQuestions,
            answeredQuestions: response.statistics.answeredQuestions,
            totalRecordingTime: response.statistics.totalRecordingTime,
            totalWords: response.statistics.totalWords
        )
        
        return ExportPreviewData(
            project: projectInfo,
            outline: chapters,
            transcript: response.transcript,
            rawText: response.rawText,
            polishedText: response.polishedText,
            statistics: statistics
        )
    }
}

// Response models for the preview API
struct ExportPreviewResponse: Codable {
    let project: ProjectPreviewInfo
    let outline: [ChapterData]
    let transcript: [[String: String]] // Simplified for now
    let rawText: String?
    let polishedText: String?
    let statistics: StatisticsData
}

struct ProjectPreviewInfo: Codable {
    let title: String
    let topic: String?
    let createdAt: Date
    let status: String
}

struct ChapterData: Codable {
    let title: String
    let order: Int
    let omitted: Bool
    let sections: [SectionData]
}

struct SectionData: Codable {
    let title: String
    let order: Int
    let omitted: Bool
    let questions: [QuestionData]
}

struct QuestionData: Codable {
    let questionId: Int
    let text: String
    let order: Int
    let omitted: Bool
    let audioSegments: [AudioSegmentData]
}

struct AudioSegmentData: Codable {
    let id: Int
    let transcriptionText: String?
    let durationSeconds: Int
}

struct StatisticsData: Codable {
    let totalQuestions: Int
    let answeredQuestions: Int
    let totalRecordingTime: Int
    let totalWords: Int
}