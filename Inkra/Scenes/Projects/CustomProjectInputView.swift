import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct CustomProjectInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var textInput: String = ""
    
    let onTopicEntered: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                headerSection
                
                textInputSection
                
                Spacer()
                
                continueButton
            }
            .padding()
            .navigationTitle("Start Your Interview")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("What's Your Story?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(ColorTheme.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Tell us what you'd like to explore. Our AI will create personalized interview questions to guide your storytelling journey.")
                .font(.body)
                .foregroundColor(ColorTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
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
                    .accessibilityIdentifier("Custom Topic Text Input")
                    .accessibilityLabel("Custom Topic Text Input")
                
                HStack {
                    Spacer()
                    
                    Text("\(textInput.count)/500")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    
    private var continueButton: some View {
        Button(action: {
            onTopicEntered(textInput.trimmingCharacters(in: .whitespacesAndNewlines))
        }) {
            HStack {
                Image(systemName: "arrow.right.circle")
                Text("Continue")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canContinue ? ColorTheme.primaryAccent : ColorTheme.primaryAccent.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(!canContinue)
        .accessibilityIdentifier("Continue with Custom Topic")
        .accessibilityLabel("Continue with Custom Topic")
    }
    
    private var canContinue: Bool {
        return !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               textInput.count <= 500
    }
    
}

#Preview {
    CustomProjectInputView { topic in
        print("Topic entered: \(topic)")
    }
}