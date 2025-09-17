import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct CreateProjectView: View {
    @EnvironmentObject private var viewModel: CreateProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // Always show traditional create view since EnhancedCreateProjectView is disabled
        traditionalCreateView
    }
    
    private var traditionalCreateView: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                topicInputSection
                
                Spacer()
                
                createButton
            }
            .padding()
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("What's your story about?")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Describe your book, memoir, or story topic. We'll create a personalized outline and interview questions for you.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var topicInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Topic")
                .font(.headline)
            
            TextEditor(text: $viewModel.topic)
                .frame(minHeight: 120)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            Text("\(viewModel.topic.count)/500")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private var createButton: some View {
        Button {
            Task {
                await viewModel.createProject()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(viewModel.isLoading ? "Creating..." : "Create Project")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(viewModel.canCreateProject ? Color.accentColor : Color(.systemGray4))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canCreateProject || viewModel.isLoading)
    }
}

#Preview {
    CreateProjectView()
}