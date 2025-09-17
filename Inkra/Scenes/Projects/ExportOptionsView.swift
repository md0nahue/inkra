import SwiftUI
import UniformTypeIdentifiers

@available(iOS 15.0, macOS 11.0, *)
struct ExportOptionsView: View {
    let project: Project
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var podcastJobId: String?
    @State private var podcastProgress: Int = 0
    @State private var showingPodcastStatus = false
    @Environment(\.dismiss) private var dismiss
    
    private let exportService = LocalExportService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Audio Export Section
                        sectionHeader(title: "Audio Export", icon: "speaker.wave.2")
                        
                        exportButton(
                            title: "Export Podcast",
                            subtitle: "Complete audio interview as MP3 file",
                            icon: "mic.fill",
                            color: .red
                        ) {
                            exportToPodcast()
                        }
                        
                        // Document Export Section
                        sectionHeader(title: "Document Export", icon: "doc")
                        
                        exportButton(
                            title: "Export PDF",
                            subtitle: "Interview transcript as PDF document",
                            icon: "doc.fill",
                            color: .red
                        ) {
                            exportToPDF()
                        }
                        
                        exportButton(
                            title: "Export DOCX",
                            subtitle: "Interview transcript as Word document",
                            icon: "doc.richtext",
                            color: .blue
                        ) {
                            exportToDOCX()
                        }
                        
                        exportButton(
                            title: "Export TXT",
                            subtitle: "Complete transcript as plain text",
                            icon: "doc.text",
                            color: .gray
                        ) {
                            exportToTXTFromAPI()
                        }
                        
                        exportButton(
                            title: "Export CSV",
                            subtitle: "Question/Answer in spreadsheet format",
                            icon: "tablecells",
                            color: .green
                        ) {
                            exportToCSVFromAPI()
                        }
                        
                        // Legacy Local Exports Section
                        sectionHeader(title: "Quick Export (Local)", icon: "square.and.arrow.up")
                        
                        exportButton(
                            title: "Questions Only (TXT)",
                            subtitle: "Questions without answers - local format",
                            icon: "doc.text",
                            color: .secondary
                        ) {
                            exportToTXT()
                        }
                        
                        exportButton(
                            title: "Q&A Pairs (CSV)",
                            subtitle: "Local question/answer pairs",
                            icon: "tablecells",
                            color: .secondary
                        ) {
                            exportToCSV()
                        }
                    }
                    .padding(.bottom, 20)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            // Clean up temporary file
            if let url = exportedFileURL {
                try? FileManager.default.removeItem(at: url)
                exportedFileURL = nil
            }
        }) {
            if let url = exportedFileURL {
                ActivityView(activityItems: [url])
            }
        }
        .alert("Export Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showingPodcastStatus) {
            PodcastStatusView(
                projectId: project.id,
                jobId: podcastJobId ?? "",
                progress: $podcastProgress,
                onComplete: { url in
                    exportedFileURL = url
                    showingPodcastStatus = false
                    showingShareSheet = true
                },
                onError: { error in
                    errorMessage = error
                    showingPodcastStatus = false
                    showingError = true
                }
            )
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Interview")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(project.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(.orange)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }
    
    private func exportButton(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .disabled(isExporting)
        .buttonStyle(PlainButtonStyle())
    }
    
    private func exportToCSV() {
        Task {
            await performExport { questions in
                return exportService.exportQuestionsToCSV(
                    LocalExportService.ExportData(
                        questions: questions,
                        projectTitle: cleanFileName(project.title)
                    )
                )
            }
        }
    }
    
    private func exportToTXT() {
        Task {
            await performExport { questions in
                return exportService.exportQuestionsToTXT(
                    LocalExportService.ExportData(
                        questions: questions,
                        projectTitle: cleanFileName(project.title)
                    )
                )
            }
        }
    }
    
    @MainActor
    private func performExport(exportFunction: @escaping ([ChapterQuestionsWithResponses]) -> URL?) async {
        isExporting = true
        errorMessage = nil
        
        do {
            // Load questions with responses
            let projectService = ProjectService()
            let response = try await projectService.getQuestionsWithResponses(projectId: project.id)
            
            // Group questions by chapter
            let grouped = Dictionary(grouping: response.questions) { question in
                question.chapterTitle
            }
            
            let questionsByChapter = grouped.map { chapterTitle, questions in
                ChapterQuestionsWithResponses(
                    chapterTitle: chapterTitle,
                    questions: questions.sorted { $0.order < $1.order }
                )
            }.sorted { $0.chapterTitle < $1.chapterTitle }
            
            if let fileURL = exportFunction(questionsByChapter) {
                exportedFileURL = fileURL
                showingShareSheet = true
            } else {
                errorMessage = "Failed to create export file"
                showingError = true
            }
            
        } catch {
            errorMessage = "Failed to load interview data: \(error.localizedDescription)"
            showingError = true
        }
        
        isExporting = false
    }
    
    // MARK: - New API Export Methods
    
    private func exportToPDF() {
        Task {
            await performAPIExport { 
                try await exportService.exportToPDF(
                    projectId: project.id,
                    projectTitle: cleanFileName(project.title)
                )
            }
        }
    }
    
    private func exportToDOCX() {
        Task {
            await performAPIExport { 
                try await exportService.exportToDOCX(
                    projectId: project.id,
                    projectTitle: cleanFileName(project.title)
                )
            }
        }
    }
    
    private func exportToTXTFromAPI() {
        Task {
            await performAPIExport { 
                try await exportService.exportToTXTFromAPI(
                    projectId: project.id,
                    projectTitle: cleanFileName(project.title),
                    includeQuestions: true
                )
            }
        }
    }
    
    private func exportToCSVFromAPI() {
        Task {
            await performAPIExport { 
                try await exportService.exportToCSVFromAPI(
                    projectId: project.id,
                    projectTitle: cleanFileName(project.title),
                    includeQuestions: true
                )
            }
        }
    }
    
    private func exportToPodcast() {
        Task {
            isExporting = true
            errorMessage = nil
            
            do {
                let response = try await exportService.startPodcastExport(projectId: project.id)
                podcastJobId = response.jobId
                podcastProgress = 0
                showingPodcastStatus = true
            } catch {
                errorMessage = "Failed to start podcast export: \(error.localizedDescription)"
                showingError = true
            }
            
            isExporting = false
        }
    }
    
    @MainActor
    private func performAPIExport(exportFunction: @escaping () async throws -> URL) async {
        isExporting = true
        errorMessage = nil
        
        do {
            let fileURL = try await exportFunction()
            exportedFileURL = fileURL
            showingShareSheet = true
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
            showingError = true
        }
        
        isExporting = false
    }
    
    private func cleanFileName(_ fileName: String) -> String {
        return fileName
            .replacingOccurrences(of: "[^a-zA-Z0-9 .-]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExportOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        ExportOptionsView(project: Project(
            id: 1,
            title: "Sample Interview",
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