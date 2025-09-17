import SwiftUI

struct EditInterestsView: View {
    @Environment(\.dismiss) var dismiss
    
    let allInterests: [Interest] = [
        .init(id: "personal_growth", name: "Personal Growth", icon: "arrow.up.right.circle"),
        .init(id: "mental_health", name: "Mental Health", icon: "brain.head.profile"),
        .init(id: "fiction_writing", name: "Fiction Writing", icon: "books.vertical"),
        .init(id: "non_fiction_writing", name: "Non-Fiction Writing", icon: "newspaper"),
        .init(id: "social_sharing", name: "Fun & Social Sharing", icon: "person.2.wave.2"),
        .init(id: "health_fitness", name: "Health & Fitness", icon: "figure.run")
    ]

    @State private var selectedInterests: Set<String> = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading your interests...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        // Header
                        VStack(spacing: 8) {
                            Text("My Interests")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Select the topics that interest you most")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Interest Selection
                        VStack(spacing: 12) {
                            ForEach(allInterests) { interest in
                                Button(action: { toggleInterest(interest.id) }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: interest.icon)
                                            .foregroundColor(.primary)
                                            .frame(width: 24)
                                        
                                        Text(interest.name)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer()
                                        
                                        if selectedInterests.contains(interest.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedInterests.contains(interest.id) ? 
                                                  Color.accentColor.opacity(0.1) : 
                                                  Color(.secondarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedInterests.contains(interest.id) ? 
                                                   Color.accentColor : 
                                                   Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        
                        // Success Message
                        if let successMessage = successMessage {
                            Text(successMessage)
                                .font(.caption)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        
                        Spacer()
                        
                        // Save Button
                        Button(action: saveInterests) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text("Save Changes")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Edit Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .task {
            await loadCurrentInterests()
        }
    }

    private func toggleInterest(_ id: String) {
        if selectedInterests.contains(id) {
            selectedInterests.remove(id)
        } else {
            selectedInterests.insert(id)
        }
        // Clear any messages when user makes changes
        errorMessage = nil
        successMessage = nil
    }

    private func loadCurrentInterests() async {
        isLoading = true
        
        do {
            let response = try await NetworkService.shared.getUserPreferences()
            await MainActor.run {
                selectedInterests = Set(response.interests)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func saveInterests() {
        errorMessage = nil
        successMessage = nil
        isSaving = true
        
        Task {
            do {
                let response = try await NetworkService.shared.updateUserInterests(Array(selectedInterests))
                await MainActor.run {
                    successMessage = response.message ?? "Interests updated successfully!"
                    isSaving = false
                }
                
                // Auto-dismiss after a short delay
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    EditInterestsView()
}