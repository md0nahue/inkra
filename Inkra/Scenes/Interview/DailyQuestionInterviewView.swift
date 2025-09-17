import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct DailyQuestionInterviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var interviewManager = InterviewManager()
    @StateObject private var questionsManager = DailyQuestionsManager()
    @State private var showingCompletedInterview = false

    var body: some View {
        NavigationView {
            ZStack {
                ColorTheme.auroraGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 56))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("Daily Reflection")
                                .font(Typography.screenTitle)
                                .foregroundColor(ColorTheme.starlightWhite)

                            Text("Guided interview with your personal questions")
                                .font(Typography.caption(14))
                                .foregroundColor(ColorTheme.moonstoneGrey)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Interview Content
                        VStack(spacing: 24) {
                            switch interviewManager.currentState {
                            case .idle:
                                idleStateView
                            case .starting:
                                loadingView("Preparing your interview...")
                            case .playingQuestion:
                                playingQuestionView
                            case .waitingForSpeech:
                                waitingForSpeechView
                            case .recording:
                                recordingView
                            case .processingAnswer:
                                loadingView("Processing your answer...")
                            case .generatingNextQuestion:
                                loadingView("Loading next question...")
                            case .paused:
                                pausedView
                            case .completed:
                                completedView
                            case .error(let message):
                                errorView(message)
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle("Daily Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        interviewManager.stopInterview()
                        dismiss()
                    }
                    .foregroundColor(ColorTheme.primaryAccent)
                }

                if interviewManager.isActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(interviewManager.canPause ? "Pause" : "Resume") {
                            if interviewManager.canPause {
                                interviewManager.pauseInterview()
                            } else {
                                Task {
                                    await interviewManager.resumeInterview()
                                }
                            }
                        }
                        .foregroundColor(ColorTheme.primaryAccent)
                    }
                }
            }
        }
        .onAppear {
            // Start daily questions interview when view appears
            Task {
                await interviewManager.startMagicalInterview(useDailyQuestions: true)
            }
        }
        .sheet(isPresented: $showingCompletedInterview) {
            CompletedInterviewView()
        }
    }

    // MARK: - View States

    @ViewBuilder
    private var idleStateView: some View {
        VStack(spacing: 24) {
            // Preview enabled questions
            VStack(alignment: .leading, spacing: 16) {
                Text("Ready for Reflection")
                    .font(Typography.cardTitle)
                    .foregroundColor(ColorTheme.starlightWhite)

                Text("You have \(questionsManager.getEnabledQuestions().count) questions ready for today's interview")
                    .font(Typography.bodyText)
                    .foregroundColor(ColorTheme.moonstoneGrey)
                    .multilineTextAlignment(.center)

                // Show preview of first few questions
                VStack(spacing: 12) {
                    ForEach(Array(questionsManager.getEnabledQuestions().prefix(3).enumerated()), id: \.1.id) { index, question in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(ColorTheme.primaryAccent)
                                .frame(width: 20, alignment: .leading)

                            Text(question.text)
                                .font(.caption)
                                .foregroundColor(ColorTheme.moonstoneGrey)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                    }

                    if questionsManager.getEnabledQuestions().count > 3 {
                        Text("+ \(questionsManager.getEnabledQuestions().count - 3) more questions")
                            .font(.caption)
                            .foregroundColor(ColorTheme.secondaryText)
                            .italic()
                    }
                }
            }
            .padding(20)
            .cosmicLofiCard()

            Button(action: {
                Task {
                    await interviewManager.startMagicalInterview(useDailyQuestions: true)
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Start Interview")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(ColorTheme.primaryAccent)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
        }
    }

    @ViewBuilder
    private func loadingView(_ message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(ColorTheme.primaryAccent)

            Text(message)
                .font(Typography.bodyText)
                .foregroundColor(ColorTheme.moonstoneGrey)
                .multilineTextAlignment(.center)
        }
        .frame(minHeight: 200)
    }

    @ViewBuilder
    private var playingQuestionView: some View {
        VStack(spacing: 24) {
            // Progress indicator
            VStack(spacing: 8) {
                HStack {
                    Text("Question \(interviewManager.questionNumber)")
                        .font(.caption)
                        .foregroundColor(ColorTheme.primaryAccent)

                    Spacer()

                    Text(String(format: "%.0f%% Complete", interviewManager.progress * 100))
                        .font(.caption)
                        .foregroundColor(ColorTheme.secondaryText)
                }

                ProgressView(value: interviewManager.progress)
                    .tint(ColorTheme.primaryAccent)
            }

            // Current question
            VStack(spacing: 16) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 48))
                    .foregroundColor(ColorTheme.primaryAccent)
                    .symbolEffect(.bounce, options: .repeat(.continuous))

                Text("Listen to the question")
                    .font(Typography.cardTitle)
                    .foregroundColor(ColorTheme.starlightWhite)

                if let currentQuestion = interviewManager.currentQuestion {
                    Text(currentQuestion.text)
                        .font(Typography.bodyText)
                        .foregroundColor(ColorTheme.moonstoneGrey)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(ColorTheme.cardBackground.opacity(0.5))
                        .cornerRadius(12)
                }
            }

            // Skip button
            if interviewManager.canSkip {
                Button(action: {
                    Task {
                        await interviewManager.skipCurrentQuestion()
                    }
                }) {
                    Text("Skip Question")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(20)
                }
            }
        }
        .padding(20)
        .cosmicLofiCard()
    }

    @ViewBuilder
    private var waitingForSpeechView: some View {
        VStack(spacing: 24) {
            // Progress
            VStack(spacing: 8) {
                HStack {
                    Text("Question \(interviewManager.questionNumber)")
                        .font(.caption)
                        .foregroundColor(ColorTheme.primaryAccent)

                    Spacer()

                    Text(String(format: "%.0f%% Complete", interviewManager.progress * 100))
                        .font(.caption)
                        .foregroundColor(ColorTheme.secondaryText)
                }

                ProgressView(value: interviewManager.progress)
                    .tint(ColorTheme.primaryAccent)
            }

            VStack(spacing: 16) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(ColorTheme.success)
                    .symbolEffect(.pulse, options: .repeat(.continuous))

                Text("Your turn to speak")
                    .font(Typography.cardTitle)
                    .foregroundColor(ColorTheme.starlightWhite)

                Text("Start speaking your response. The interview will automatically continue when you finish.")
                    .font(Typography.caption(14))
                    .foregroundColor(ColorTheme.moonstoneGrey)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button(action: {
                    Task {
                        await interviewManager.skipCurrentQuestion()
                    }
                }) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(20)
                }

                Button(action: {
                    interviewManager.pauseInterview()
                }) {
                    Text("Pause")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.primaryAccent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(ColorTheme.primaryAccent.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(20)
        .cosmicLofiCard()
    }

    @ViewBuilder
    private var recordingView: some View {
        VStack(spacing: 24) {
            // Progress
            VStack(spacing: 8) {
                HStack {
                    Text("Question \(interviewManager.questionNumber)")
                        .font(.caption)
                        .foregroundColor(ColorTheme.primaryAccent)

                    Spacer()

                    Text("Recording...")
                        .font(.caption)
                        .foregroundColor(ColorTheme.error)
                }

                ProgressView(value: interviewManager.progress)
                    .tint(ColorTheme.primaryAccent)
            }

            VStack(spacing: 16) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(ColorTheme.error)
                    .symbolEffect(.variableColor, options: .repeat(.continuous))

                Text("Recording your response")
                    .font(Typography.cardTitle)
                    .foregroundColor(ColorTheme.starlightWhite)

                Text("Keep speaking naturally. The recording will automatically stop when you finish.")
                    .font(Typography.caption(14))
                    .foregroundColor(ColorTheme.moonstoneGrey)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                Task {
                    await interviewManager.finishRecording()
                }
            }) {
                HStack {
                    Image(systemName: "stop.circle")
                    Text("Finish Response")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(ColorTheme.error)
                .cornerRadius(25)
            }
        }
        .padding(20)
        .cosmicLofiCard()
    }

    @ViewBuilder
    private var pausedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(ColorTheme.warning)

            Text("Interview Paused")
                .font(Typography.cardTitle)
                .foregroundColor(ColorTheme.starlightWhite)

            Button(action: {
                Task {
                    await interviewManager.resumeInterview()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle")
                    Text("Resume")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(ColorTheme.primaryAccent)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
        }
        .padding(20)
        .cosmicLofiCard()
    }

    @ViewBuilder
    private var completedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(ColorTheme.success)

            Text("Interview Complete!")
                .font(Typography.screenTitle)
                .foregroundColor(ColorTheme.starlightWhite)

            Text("Thank you for taking time to reflect today. Your responses have been saved.")
                .font(Typography.bodyText)
                .foregroundColor(ColorTheme.moonstoneGrey)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: {
                    showingCompletedInterview = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("View Responses")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ColorTheme.primaryAccent)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }

                Button(action: {
                    dismiss()
                }) {
                    Text("Done")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.primaryAccent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(25)
                }
            }
        }
        .padding(20)
        .cosmicLofiCard()
        .onAppear {
            // Auto-dismiss after a delay if user doesn't interact
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if interviewManager.currentState == .completed {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(ColorTheme.error)

            Text("Something went wrong")
                .font(Typography.cardTitle)
                .foregroundColor(ColorTheme.starlightWhite)

            Text(message)
                .font(Typography.bodyText)
                .foregroundColor(ColorTheme.moonstoneGrey)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await interviewManager.startMagicalInterview(useDailyQuestions: true)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ColorTheme.primaryAccent)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }

                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(25)
                }
            }
        }
        .padding(20)
        .cosmicLofiCard()
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct CompletedInterviewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                ColorTheme.primaryBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("🎉")
                        .font(.system(size: 64))

                    Text("Your reflection interview is complete!")
                        .font(Typography.cardTitle)
                        .foregroundColor(ColorTheme.starlightWhite)
                        .multilineTextAlignment(.center)

                    Text("Your responses are being processed and will appear in your interview history shortly.")
                        .font(Typography.bodyText)
                        .foregroundColor(ColorTheme.moonstoneGrey)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(ColorTheme.primaryAccent)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(24)
            }
            .navigationTitle("Complete!")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    DailyQuestionInterviewView()
}