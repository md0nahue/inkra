import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct TypeYourTopicView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var topicText = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToPresets = false
    @State private var showLoadingScreen = false
    @State private var currentPlaceholder = ""
    @FocusState private var isTextFieldFocused: Bool
    
    let onTopicEntered: (String) -> Void
    
    // Preset topics for random placeholder generation
    private let presetTopics = [
        "Getting over a breakup",
        "Looking for new love", 
        "The hardest thing that ever happened to me",
        "The best thing that ever happened to me",
        "The funniest thing that ever happened to me",
        "My biggest achievement",
        "A time I overcame fear",
        "My dreams and aspirations",
        "Childhood memories",
        "A life-changing decision",
        "Lessons learned from failure",
        "My role models and why",
        "What makes me happy",
        "My biggest regret",
        "A moment of pure joy",
        "How I've changed over the years",
        "My family story",
        "Adventures and travels",
        "Career journey and ambitions",
        "Friendships that shaped me"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Compact Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image("octopus-transparent-background")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .colorMultiply(.white)
                    }
                    
                    Text("What's your story?")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(ColorTheme.primaryText)
                    
                    Text("Type what you'd like to talk about")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Text input area
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if topicText.isEmpty {
                            Text(currentPlaceholder)
                                .font(.body)
                                .foregroundColor(ColorTheme.tertiaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .animation(.easeInOut(duration: 0.5), value: currentPlaceholder)
                        }
                        
                        if #available(iOS 16.0, *) {
                            TextEditor(text: $topicText)
                                .font(.body)
                                .foregroundColor(ColorTheme.primaryText)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .focused($isTextFieldFocused)
                        } else {
                            TextEditor(text: $topicText)
                                .font(.body)
                                .foregroundColor(ColorTheme.primaryText)
                                .padding(8)
                                .background(Color.clear)
                                .focused($isTextFieldFocused)
                        }
                    }
                    .frame(minHeight: 200, maxHeight: 300)
                    .background(ColorTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTextFieldFocused ? ColorTheme.primaryAccent : ColorTheme.primaryAccent.opacity(0.2), lineWidth: isTextFieldFocused ? 2 : 1)
                    )
                    .padding(.horizontal, 24)
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    // Submit button
                    Button(action: {
                        submitTopic()
                    }) {
                        HStack {
                            Text("Create Interview")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: topicText.count >= 10 ? [ColorTheme.primaryAccent, ColorTheme.secondaryAccent] : [Color.gray, Color.gray.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                    }
                    .disabled(topicText.count < 10 || isProcessing)
                    .padding(.horizontal, 24)
                    
                    // Interview Ideas button
                    Button(action: {
                        navigateToPresets = true
                    }) {
                        HStack(spacing: 12) {
                            Image("octopus-transparent-background")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            
                            Text("Get Interview Ideas")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ColorTheme.primaryAccent)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(ColorTheme.primaryAccent, lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(ColorTheme.primaryAccent.opacity(0.1))
                                )
                        )
                    }
                    
                    // Helper text
                    Text("Minimum 10 characters required")
                        .font(.caption)
                        .foregroundColor(ColorTheme.tertiaryText)
                }
                .padding(.bottom, 40)
                .padding(.top, 24)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .disabled(isProcessing || showLoadingScreen)
        .sheet(isPresented: $navigateToPresets) {
            PresetTopicsView { selectedTopic in
                navigateToPresets = false
                // Use the selected topic
                topicText = selectedTopic
            }
        }
        .overlay {
            if showLoadingScreen {
                InterviewCreationLoadingView(
                    onError: {
                        // Handle loading error gracefully
                        showLoadingScreen = false
                        showError = true
                        errorMessage = "There was an issue processing your request. Please try again."
                    },
                    onDismiss: {
                        // Dismiss loading screen
                        showLoadingScreen = false
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                .zIndex(1000)
            }
        }
        .onAppear {
            // Set initial random placeholder
            updatePlaceholder()
            
            // Auto-focus the text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
            
            // Start placeholder rotation timer
            startPlaceholderRotation()
        }
    }
    
    private func updatePlaceholder() {
        let randomTopic = presetTopics.randomElement() ?? "Your story here"
        currentPlaceholder = "Example: \(randomTopic)..."
    }
    
    private func startPlaceholderRotation() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            // Only update if text field is empty and not focused
            if topicText.isEmpty && !isTextFieldFocused {
                withAnimation(.easeInOut(duration: 0.5)) {
                    updatePlaceholder()
                }
            }
        }
    }
    
    private func submitTopic() {
        // Validate minimum length
        guard topicText.count >= 10 else {
            errorMessage = "Please enter at least 10 characters to describe your topic"
            showError = true
            return
        }
        
        // Validate maximum length
        guard topicText.count <= 2000 else {
            errorMessage = "Topic description is too long. Please keep it under 2000 characters"
            showError = true
            return
        }
        
        // Trim whitespace
        let trimmedTopic = topicText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTopic.isEmpty else {
            errorMessage = "Please enter a valid topic"
            showError = true
            return
        }
        
        // Hide keyboard
        isTextFieldFocused = false
        
        // Show loading and process
        isProcessing = true
        showLoadingScreen = true
        
        // Small delay for UI transition, then call the callback
        // The callback (from VoiceInterviewTopicView) will handle the async project creation
        // and navigation. Keep loading screen active until parent handles navigation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onTopicEntered(trimmedTopic)
        }
    }
}

#Preview {
    TypeYourTopicView { topic in
        print("Topic entered: \(topic)")
    }
}