import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct VoiceTextInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateProjectViewModel()
    @State private var textInput: String = ""
    
    let onProjectCreated: (Project) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    textInputSection
                    
                    // Add some bottom padding to ensure button visibility
                    createButton
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("Start Your Interview")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .onChange(of: viewModel.createdProject) { project in
                if let project = project {
                    onProjectCreated(project)
                    dismiss()
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("What's Your Story?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(ColorTheme.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Tell us what you'd like to explore. Our AI will create personalized interview questions to guide your storytelling journey.")
                .font(.subheadline)
                .foregroundColor(ColorTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
    }
    
    
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Describe Your Topic")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $textInput)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(ColorTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorTheme.primaryAccent.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if textInput.isEmpty {
                                Text("e.g., My childhood memories, Career journey, Life lessons, Family stories...")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        }, alignment: .topLeading
                    )
                
                HStack {
                    Spacer()
                    
                    Text("\(textInput.count)/500")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    
    private var createButton: some View {
        Button(action: createProject) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                
                Text(viewModel.isLoading ? "Creating Interview..." : "Create Interview")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canCreate ? ColorTheme.primaryAccent : ColorTheme.primaryAccent.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(!canCreate || viewModel.isLoading)
    }
    
    private var canCreate: Bool {
        return !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               textInput.count <= 500 &&
               !viewModel.isLoading
    }
    
    
    private func createProject() {
        viewModel.topic = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            await viewModel.createProject()
        }
    }
}

#Preview {
    VoiceTextInputView { project in
        print("Project created: \(project.title)")
    }
}