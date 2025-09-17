import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct ExportPreviewView: View {
    let project: Project
    @StateObject private var viewModel: ExportPreviewViewModel
    @State private var selectedPreviewMode: PreviewMode = .withQuestions
    @State private var selectedTranscriptVersion: TranscriptVersion = .edited
    @State private var showingExportMenu = false
    @State private var showingPodcastExportDialog = false
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: ExportPreviewViewModel(project: project))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview Controls
                VStack(spacing: 16) {
                    HStack {
                        Text("Preview Mode")
                            .font(.headline)
                        Spacer()
                        Picker("Preview Mode", selection: $selectedPreviewMode) {
                            ForEach(PreviewMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    }
                    
                    HStack {
                        Text("Transcript Version")
                            .font(.headline)
                        Spacer()
                        Picker("Transcript Version", selection: $selectedTranscriptVersion) {
                            ForEach(TranscriptVersion.allCases) { version in
                                Text(version.displayName).tag(version)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                
                Divider()
                
                // Preview Content
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView("Loading preview...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let previewData = viewModel.previewData {
                            previewContent(for: previewData)
                        } else {
                            Text("No preview data available")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing:
                    Menu("Export") {
                        Button(action: {
                            // Traditional export actions (text, PDF, etc.)
                            // TODO: Implement traditional export
                        }) {
                            Label("Export Text", systemImage: "doc.text")
                        }
                        
                        Button(action: {
                            showingPodcastExportDialog = true
                        }) {
                            Label("Export Podcast", systemImage: "mic.badge.plus")
                        }
                        .disabled(viewModel.previewData == nil)
                    }
                    .disabled(viewModel.previewData == nil)
            )
        }
        .task {
            await viewModel.loadPreviewData()
        }
        .onChange(of: selectedPreviewMode) { _ in
            Task<Void, Never> {
                await viewModel.loadPreviewData()
            }
        }
        .onChange(of: selectedTranscriptVersion) { _ in
            Task<Void, Never> {
                await viewModel.loadPreviewData()
            }
        }
        .sheet(isPresented: $showingPodcastExportDialog) {
            // Podcast export functionality removed during refactor
            Text("Podcast export feature is temporarily unavailable")
                .padding()
        }
    }
    
    @ViewBuilder
    private func previewContent(for data: ExportPreviewData) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            headerSection(for: data)
            
            // Statistics
            statisticsSection(for: data)
            
            Divider()
            
            // Content based on preview mode
            switch selectedPreviewMode {
            case .withQuestions:
                questionAnswerContent(for: data)
            case .withoutQuestions:
                transcriptOnlyContent(for: data)
            case .rawTranscript:
                rawTranscriptContent(for: data)
            case .editedTranscript:
                editedTranscriptContent(for: data)
            }
        }
    }
    
    private func headerSection(for data: ExportPreviewData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.project.title)
                .font(.title)
                .fontWeight(.bold)
            
            if let topic = data.project.topic {
                Text("Topic: \(topic)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Generated: \(Date().formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Status: \(data.project.status.capitalized)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func statisticsSection(for data: ExportPreviewData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATISTICS")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Questions: \(data.statistics.totalQuestions)")
                        .font(.caption)
                    Text("Answered: \(data.statistics.answeredQuestions)")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Words: \(data.statistics.totalWords)")
                        .font(.caption)
                    Text("Time: \(formatDuration(data.statistics.totalRecordingTime))")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func questionAnswerContent(for data: ExportPreviewData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("INTERVIEW TRANSCRIPT (WITH QUESTIONS)")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(data.outline, id: \.title) { chapter in
                if !chapter.omitted {
                    chapterWithQuestionsView(chapter)
                }
            }
        }
    }
    
    private func transcriptOnlyContent(for data: ExportPreviewData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("INTERVIEW TRANSCRIPT (WITHOUT QUESTIONS)")
                .font(.headline)
                .fontWeight(.semibold)
            
            if selectedTranscriptVersion == .raw, let rawText = data.rawText {
                Text(rawText)
                    .font(.body)
                    .textSelection(.enabled)
            } else if let polishedText = data.polishedText {
                Text(polishedText)
                    .font(.body)
                    .textSelection(.enabled)
            } else {
                ForEach(Array(data.transcript.indices), id: \.self) { index in
                    transcriptItemView(data.transcript[index])
                }
            }
        }
    }
    
    private func rawTranscriptContent(for data: ExportPreviewData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RAW TRANSCRIPT")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let rawText = data.rawText {
                Text(rawText)
                    .font(.body)
                    .textSelection(.enabled)
            } else {
                Text("Raw transcript not available")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func editedTranscriptContent(for data: ExportPreviewData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("EDITED TRANSCRIPT")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let polishedText = data.polishedText {
                Text(polishedText)
                    .font(.body)
                    .textSelection(.enabled)
            } else {
                Text("Edited transcript not available")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func chapterWithQuestionsView(_ chapter: ChapterPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chapter.title)
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(chapter.sections, id: \.title) { section in
                if !section.omitted {
                    sectionWithQuestionsView(section)
                }
            }
        }
    }
    
    private func sectionWithQuestionsView(_ section: SectionPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            
            ForEach(section.questions, id: \.questionId) { question in
                if !question.omitted {
                    questionAnswerView(question)
                }
            }
        }
    }
    
    private func questionAnswerView(_ question: QuestionPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Q: \(question.text)")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            ForEach(question.audioSegments, id: \.id) { segment in
                if let transcriptionText = segment.transcriptionText {
                    Text(transcriptionText)
                        .font(.body)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.leading, 16)
    }
    
    private func transcriptItemView(_ item: [String: Any]) -> some View {
        // This would need to be implemented based on the actual transcript structure
        Text("Transcript item placeholder")
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(remainingSeconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

enum PreviewMode: String, CaseIterable, Identifiable {
    case withQuestions = "with_questions"
    case withoutQuestions = "without_questions"
    case rawTranscript = "raw_transcript"
    case editedTranscript = "edited_transcript"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .withQuestions:
            return "With Questions"
        case .withoutQuestions:
            return "Without Questions"
        case .rawTranscript:
            return "Raw Transcript"
        case .editedTranscript:
            return "Edited Transcript"
        }
    }
}

enum TranscriptVersion: String, CaseIterable, Identifiable {
    case raw = "raw"
    case edited = "edited"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .raw:
            return "Raw"
        case .edited:
            return "Edited"
        }
    }
}

// Preview Data Models
struct ExportPreviewData {
    let project: ProjectInfo
    let outline: [ChapterPreview]
    let transcript: [[String: Any]]
    let rawText: String?
    let polishedText: String?
    let statistics: StatisticsPreview
}

struct ProjectInfo {
    let title: String
    let topic: String?
    let createdAt: Date
    let status: String
}

struct ChapterPreview {
    let title: String
    let order: Int
    let omitted: Bool
    let sections: [SectionPreview]
}

struct SectionPreview {
    let title: String
    let order: Int
    let omitted: Bool
    let questions: [QuestionPreview]
}

struct QuestionPreview {
    let questionId: Int
    let text: String
    let order: Int
    let omitted: Bool
    let audioSegments: [AudioSegmentPreview]
}

struct AudioSegmentPreview {
    let id: Int
    let transcriptionText: String?
    let durationSeconds: Int
}

struct StatisticsPreview {
    let totalQuestions: Int
    let answeredQuestions: Int
    let totalRecordingTime: Int
    let totalWords: Int
}

struct ExportPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ExportPreviewView(project: Project(
            id: 1,
            title: "Sample Project",
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