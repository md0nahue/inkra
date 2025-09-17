import Foundation

struct DailyQuestion: Identifiable, Codable, Hashable {
    let id = UUID()
    var text: String
    var isEnabled: Bool = true
    var category: QuestionCategory = .general
    var order: Int = 0

    enum QuestionCategory: String, CaseIterable, Codable {
        case personal = "Personal"
        case professional = "Professional"
        case creative = "Creative"
        case reflective = "Reflective"
        case general = "General"

        var icon: String {
            switch self {
            case .personal:
                return "person.fill"
            case .professional:
                return "briefcase.fill"
            case .creative:
                return "lightbulb.fill"
            case .reflective:
                return "brain.head.profile"
            case .general:
                return "questionmark.circle.fill"
            }
        }
    }

    static let defaultQuestions: [DailyQuestion] = [
        DailyQuestion(text: "What's the most important thing you learned today?", category: .reflective, order: 0),
        DailyQuestion(text: "What was the highlight of your day?", category: .personal, order: 1),
        DailyQuestion(text: "What challenged you most today and how did you handle it?", category: .reflective, order: 2),
        DailyQuestion(text: "What are you most grateful for right now?", category: .personal, order: 3),
        DailyQuestion(text: "If you could change one thing about today, what would it be?", category: .reflective, order: 4),
        DailyQuestion(text: "What goal are you working towards and how did you progress today?", category: .professional, order: 5),
        DailyQuestion(text: "What's something creative you'd like to explore?", category: .creative, order: 6),
        DailyQuestion(text: "How are you feeling about your current direction in life?", category: .personal, order: 7),
        DailyQuestion(text: "What advice would you give to someone facing a similar situation to yours?", category: .reflective, order: 8),
        DailyQuestion(text: "What's something you're looking forward to?", category: .general, order: 9)
    ]
}

class DailyQuestionsManager: ObservableObject {
    @Published var questions: [DailyQuestion] = []

    private let userDefaultsKey = "daily_questions"

    init() {
        loadQuestions()
    }

    func loadQuestions() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([DailyQuestion].self, from: data) {
            self.questions = decoded
        } else {
            // Load default questions if none exist
            self.questions = DailyQuestion.defaultQuestions
            saveQuestions()
        }
    }

    func saveQuestions() {
        if let encoded = try? JSONEncoder().encode(questions) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func addQuestion(_ question: DailyQuestion) {
        var newQuestion = question
        newQuestion.order = questions.count
        questions.append(newQuestion)
        saveQuestions()
    }

    func removeQuestion(_ question: DailyQuestion) {
        questions.removeAll { $0.id == question.id }
        reorderQuestions()
        saveQuestions()
    }

    func updateQuestion(_ question: DailyQuestion) {
        if let index = questions.firstIndex(where: { $0.id == question.id }) {
            questions[index] = question
            saveQuestions()
        }
    }

    func moveQuestion(from source: IndexSet, to destination: Int) {
        questions.move(fromOffsets: source, toOffset: destination)
        reorderQuestions()
        saveQuestions()
    }

    func resetToDefaults() {
        questions = DailyQuestion.defaultQuestions
        saveQuestions()
    }

    private func reorderQuestions() {
        for (index, question) in questions.enumerated() {
            questions[index].order = index
        }
    }

    func getRandomEnabledQuestion() -> DailyQuestion? {
        let enabledQuestions = questions.filter { $0.isEnabled }
        return enabledQuestions.randomElement()
    }

    func getEnabledQuestions() -> [DailyQuestion] {
        return questions.filter { $0.isEnabled }
    }
}