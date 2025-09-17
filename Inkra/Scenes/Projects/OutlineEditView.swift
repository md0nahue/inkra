import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 15.0, macOS 11.0, *)
struct OutlineEditView: View {
    let project: Project
    @StateObject private var viewModel: OutlineEditViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: OutlineEditViewModel(project: project))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if let outline = viewModel.currentProject.outline {
                        ForEach(outline.chapters) { chapter in
                            chapterSection(chapter)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Outline")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveChanges()
                            if !viewModel.showError {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.hasChanges || viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private func chapterSection(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            chapterHeader(chapter)
            
            ForEach(chapter.sections) { section in
                sectionRow(section)
                
                ForEach(section.questions) { question in
                    questionRow(question)
                }
            }
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(12)
    }
    
    private func chapterHeader(_ chapter: Chapter) -> some View {
        let isOmitted = viewModel.isChapterOmitted(chapter.id)
        
        return Button {
            #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            #endif
            viewModel.toggleChapter(chapter.id)
        } label: {
            HStack(spacing: 0) {
                Text(chapter.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .strikethrough(isOmitted)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: isOmitted ? "checkmark.circle.fill" : "minus.circle.fill")
                    Text(isOmitted ? "Restore" : "Remove")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(isOmitted ? .green : .red)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(!isOmitted ? Color.red.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func sectionRow(_ section: Section) -> some View {
        let isOmitted = viewModel.isSectionOmitted(section.id)
        
        return Button {
            #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            #endif
            viewModel.toggleSection(section.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(isOmitted)
                    
                    Text("\(section.questions.count) questions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: isOmitted ? "checkmark.circle.fill" : "minus.circle.fill")
                    Text(isOmitted ? "Restore" : "Remove")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(isOmitted ? .green : .red)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(!isOmitted ? Color.red.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 20)
    }
    
    private func questionRow(_ question: Question) -> some View {
        let isOmitted = viewModel.isQuestionOmitted(question.id)
        
        return Button {
            #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            #endif
            viewModel.toggleQuestion(question.id)
        } label: {
            HStack(spacing: 0) {
                Text(question.text)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .strikethrough(isOmitted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 8)
                
                HStack(spacing: 4) {
                    Image(systemName: isOmitted ? "checkmark.circle.fill" : "minus.circle.fill")
                    Text(isOmitted ? "Restore" : "Remove")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(isOmitted ? .green : .red)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(!isOmitted ? Color.red.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Outline Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("The outline is still being generated. Please check back later.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct OutlineEditView_Previews: PreviewProvider {
    static var previews: some View {
        OutlineEditView(project: Project(
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