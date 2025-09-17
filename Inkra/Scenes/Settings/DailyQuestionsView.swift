import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct DailyQuestionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var questionsManager = DailyQuestionsManager()
    @State private var showingAddQuestion = false
    @State private var showingEditQuestion: DailyQuestion?
    @State private var newQuestionText = ""
    @State private var newQuestionCategory: DailyQuestion.QuestionCategory = .general
    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                ColorTheme.primaryBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "questionmark.diamond")
                                .font(.system(size: 48))
                                .foregroundColor(ColorTheme.primaryAccent)

                            Text("Daily Questions")
                                .font(Typography.screenTitle)
                                .foregroundColor(ColorTheme.starlightWhite)

                            Text("Customize the questions for your daily reflection interviews")
                                .font(Typography.caption(14))
                                .foregroundColor(ColorTheme.moonstoneGrey)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Action Buttons
                        HStack(spacing: 16) {
                            Button(action: { showingAddQuestion = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                    Text("Add Question")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(ColorTheme.primaryAccent)
                                .cornerRadius(25)
                            }

                            Button(action: { showingResetAlert = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Reset to Defaults")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(ColorTheme.primaryAccent)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(ColorTheme.cardBackground)
                                .cornerRadius(25)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(ColorTheme.primaryAccent.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)

                        // Questions List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Questions (\(questionsManager.questions.filter { $0.isEnabled }.count) enabled)")
                                .font(Typography.cardTitle)
                                .foregroundColor(ColorTheme.starlightWhite)
                                .padding(.horizontal, 24)

                            LazyVStack(spacing: 12) {
                                ForEach(questionsManager.questions.indices, id: \.self) { index in
                                    QuestionRowView(
                                        question: $questionsManager.questions[index],
                                        onEdit: { question in
                                            showingEditQuestion = question
                                        },
                                        onDelete: { question in
                                            questionsManager.removeQuestion(question)
                                        },
                                        onToggle: { question in
                                            questionsManager.updateQuestion(question)
                                        }
                                    )
                                }
                                .onMove(perform: questionsManager.moveQuestion)
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle("Daily Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                        .foregroundColor(ColorTheme.primaryAccent)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ColorTheme.primaryAccent)
                }
            }
        }
        .sheet(isPresented: $showingAddQuestion) {
            AddEditQuestionView(
                questionText: $newQuestionText,
                category: $newQuestionCategory,
                title: "Add Question"
            ) {
                let newQuestion = DailyQuestion(
                    text: newQuestionText,
                    category: newQuestionCategory
                )
                questionsManager.addQuestion(newQuestion)
                newQuestionText = ""
                newQuestionCategory = .general
            }
        }
        .sheet(item: $showingEditQuestion) { question in
            AddEditQuestionView(
                questionText: .constant(question.text),
                category: .constant(question.category),
                title: "Edit Question"
            ) {
                var updatedQuestion = question
                questionsManager.updateQuestion(updatedQuestion)
            }
        }
        .alert("Reset to Defaults", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                questionsManager.resetToDefaults()
            }
        } message: {
            Text("This will replace all your current questions with the default set. This action cannot be undone.")
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct QuestionRowView: View {
    @Binding var question: DailyQuestion
    let onEdit: (DailyQuestion) -> Void
    let onDelete: (DailyQuestion) -> Void
    let onToggle: (DailyQuestion) -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Category Icon
            Image(systemName: question.category.icon)
                .font(.system(size: 20))
                .foregroundColor(ColorTheme.primaryAccent)
                .frame(width: 24)

            // Question Text
            VStack(alignment: .leading, spacing: 4) {
                Text(question.text)
                    .font(Typography.bodyText)
                    .foregroundColor(question.isEnabled ? ColorTheme.starlightWhite : ColorTheme.moonstoneGrey)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(question.category.rawValue)
                        .font(.caption)
                        .foregroundColor(ColorTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ColorTheme.primaryAccent.opacity(0.2))
                        .cornerRadius(4)

                    Spacer()
                }
            }

            Spacer()

            // Controls
            VStack(spacing: 8) {
                Button(action: { onEdit(question) }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(ColorTheme.primaryAccent)
                }

                Toggle("", isOn: Binding(
                    get: { question.isEnabled },
                    set: { newValue in
                        question.isEnabled = newValue
                        onToggle(question)
                    }
                ))
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.8)
            }
        }
        .padding(20)
        .cosmicLofiCard()
        .opacity(question.isEnabled ? 1.0 : 0.7)
        .contextMenu {
            Button("Edit") {
                onEdit(question)
            }

            Button("Delete", role: .destructive) {
                onDelete(question)
            }
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct AddEditQuestionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var questionText: String
    @Binding var category: DailyQuestion.QuestionCategory
    let title: String
    let onSave: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                ColorTheme.primaryBackground.ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 48))
                            .foregroundColor(ColorTheme.primaryAccent)

                        Text(title)
                            .font(Typography.screenTitle)
                            .foregroundColor(ColorTheme.starlightWhite)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 24) {
                        // Question Text
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Question Text")
                                .font(Typography.cardTitle)
                                .foregroundColor(ColorTheme.starlightWhite)

                            TextEditor(text: $questionText)
                                .font(Typography.bodyText)
                                .foregroundColor(ColorTheme.primaryText)
                                .frame(minHeight: 100)
                                .padding()
                                .background(ColorTheme.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(ColorTheme.cardBorder, lineWidth: 1)
                                )
                        }

                        // Category Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(Typography.cardTitle)
                                .foregroundColor(ColorTheme.starlightWhite)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(DailyQuestion.QuestionCategory.allCases, id: \.self) { cat in
                                        Button(action: { category = cat }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: cat.icon)
                                                Text(cat.rawValue)
                                            }
                                            .font(.subheadline)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(category == cat ? ColorTheme.primaryAccent : ColorTheme.cardBackground)
                                            .foregroundColor(category == cat ? .white : ColorTheme.primaryText)
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(ColorTheme.primaryAccent.opacity(category == cat ? 0 : 0.3), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }

                        // Save Button
                        Button(action: {
                            onSave()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Save Question")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ColorTheme.moonstoneGrey : ColorTheme.primaryAccent)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .disabled(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ColorTheme.primaryAccent)
                }
            }
        }
    }
}

#Preview {
    DailyQuestionsView()
}