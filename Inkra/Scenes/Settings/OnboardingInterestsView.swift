import SwiftUI

struct Interest: Identifiable {
    let id: String
    let name: String
    let icon: String
}

struct OnboardingInterestsView: View {
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
    @State private var errorMessage: String?
    let onComplete: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("How will you use Inkra?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Select one or more. This helps us personalize your experience.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
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
                .padding(.horizontal, 32)
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Continue Button
                Button(action: saveInterests) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Continue")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedInterests.isEmpty || isLoading)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
    }

    private func toggleInterest(_ id: String) {
        if selectedInterests.contains(id) {
            selectedInterests.remove(id)
        } else {
            selectedInterests.insert(id)
        }
    }

    private func saveInterests() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                let response = try await NetworkService.shared.updateUserInterests(Array(selectedInterests))
                await MainActor.run {
                    // Auth disabled in V1 - interests saved locally
                    isLoading = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    OnboardingInterestsView {
        print("Onboarding completed")
    }
}