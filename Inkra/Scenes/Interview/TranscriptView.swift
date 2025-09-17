import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 15.0, macOS 11.0, *)
struct TranscriptView: View {
    let project: Project
    @StateObject private var viewModel: TranscriptViewModel
    @State private var showingEditAlert = false
    @State private var showingShareSheet = false
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: TranscriptViewModel(project: project))
    }
    
    var body: some View {
        Group {
            if !viewModel.canViewTranscript {
                noTranscriptView
            } else if viewModel.isLoading {
                loadingView
            } else if viewModel.hasFailed {
                errorView
            } else if viewModel.hasQuestionsData {
                questionsAndAnswersView
            } else {
                noDataView
            }
        }
        .navigationTitle("Transcript")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if viewModel.hasQuestionsData {
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await viewModel.loadTranscript()
        }
        .refreshable {
            await viewModel.refreshTranscript()
        }
        .sheet(isPresented: $viewModel.isEditing) {
            editingView
        }
        .sheet(isPresented: $showingShareSheet) {
            // ShareSheet removed during refactor
            Text("Share feature is temporarily unavailable")
                .padding()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var noTranscriptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Transcript Not Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("The transcript will be available once your interview is completed and processed.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(viewModel.currentLoadingText)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if viewModel.isProcessing {
                Text("This may take a few minutes...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Failed to Load Transcript")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("There was an error processing your transcript. Please try again later.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                Task {
                    await viewModel.loadTranscript()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Questions or Answers Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start your interview to see questions and answers appear here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var transcriptContentView: some View {
        VStack(spacing: 0) {
            if viewModel.isTranscriptReady {
                displayModePicker
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(viewModel.groupedContent.enumerated()), id: \.offset) { index, group in
                        contentGroupView(group)
                    }
                }
                .padding()
            }
        }
    }
    
    private var displayModePicker: some View {
        Picker("Display Mode", selection: $viewModel.displayMode) {
            ForEach(TranscriptViewModel.TranscriptDisplayMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func contentGroupView(_ group: ContentGroup) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let chapterTitle = group.chapter.title {
                Text(chapterTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            if let section = group.section, let sectionTitle = section.title {
                Text(sectionTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            ForEach(Array(group.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                if let text = paragraph.text {
                    Text(text)
                        .font(.body)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
    
    private var editingView: some View {
        NavigationView {
            VStack {
                TextEditor(text: $viewModel.editedContent)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Edit Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if viewModel.hasUnsavedChanges {
                            showingEditAlert = true
                        } else {
                            viewModel.cancelEditing()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveEditing()
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.editedContent.isEmpty)
                }
            }
            .alert("Unsaved Changes", isPresented: $showingEditAlert) {
                Button("Discard", role: .destructive) {
                    viewModel.cancelEditing()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        }
    }
    
    private var questionsAndAnswersView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                ForEach(Array(viewModel.questionsByChapter.enumerated()), id: \.offset) { index, chapter in
                    // Show all chapters that have questions, not just answered ones
                    if !chapter.questions.isEmpty {
                        chapterQASection(chapter)
                    }
                }
            }
            .padding()
        }
    }
    
    private func hasAnsweredQuestions(in chapter: ChapterQuestionsWithResponses) -> Bool {
        chapter.questions.contains { question in
            (question.transcribedResponse != nil && !question.transcribedResponse!.isEmpty) || question.hasResponse
        }
    }
    
    private func chapterQASection(_ chapter: ChapterQuestionsWithResponses) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Chapter header
            Text(chapter.chapterTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Show all questions, not just ones with answers
            ForEach(Array(chapter.questions.enumerated()), id: \.offset) { index, question in
                questionAndAnswerRow(question, number: index + 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
    
    private func questionAndAnswerRow(_ question: InterviewQuestionWithResponse, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question
            HStack(alignment: .top, spacing: 8) {
                Text("Q.")
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
            
            // Answer
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
                        Text("Audio recorded - transcript pending")
                            .font(.body)
                            .foregroundColor(.blue)
                            .italic()
                        
                        if let duration = question.responseDuration {
                            Text("Duration: \(Int(duration))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No response recorded")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// ShareSheet moved to shared location to avoid duplication

struct TranscriptView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptView(project: Project(
            id: 1,
            title: "My Test Project",
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