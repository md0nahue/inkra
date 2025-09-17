import SwiftUI
import UniformTypeIdentifiers

@available(iOS 15.0, macOS 11.0, *)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var questionsManager = DailyQuestionsManager()
    @State private var showingVoiceSettings = false
    @State private var showingDailyQuestions = false
    @State private var showingAccountSettings = false
    @State private var showingAudioSettings = false
    @State private var showingFeedback = false
    @State private var showingDiagnostics = false
    @State private var showingImportDialog = false
    @State private var showingExportDialog = false
    @State private var importDocument: SettingsDocument?
    @State private var exportResult: String?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                ColorTheme.auroraGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 48))
                                .foregroundColor(ColorTheme.primaryAccent)

                            Text("Settings")
                                .font(Typography.screenTitle)
                                .foregroundColor(ColorTheme.starlightWhite)

                            Text("Configure your Inkra experience")
                                .font(Typography.caption(14))
                                .foregroundColor(ColorTheme.moonstoneGrey)
                        }
                        .padding(.top, 20)

                        // Interview Settings Section
                        SettingsSection(title: "Interview", icon: "waveform.and.mic") {
                            SettingsRow(
                                title: "Voice Settings",
                                subtitle: "Configure AI voice and speech rate",
                                icon: "speaker.wave.2.fill",
                                action: { showingVoiceSettings = true }
                            )

                            SettingsRow(
                                title: "Daily Questions",
                                subtitle: "\(questionsManager.questions.count) questions configured",
                                icon: "questionmark.diamond.fill",
                                action: { showingDailyQuestions = true }
                            )

                            SettingsRow(
                                title: "Audio Settings",
                                subtitle: "Playback and recording preferences",
                                icon: "speaker.wave.3.fill",
                                action: { showingAudioSettings = true }
                            )
                        }

                        // Data & Privacy Section
                        SettingsSection(title: "Data & Privacy", icon: "shield.fill") {
                            SettingsRow(
                                title: "Account Settings",
                                subtitle: "Profile and security settings",
                                icon: "person.circle.fill",
                                action: { showingAccountSettings = true }
                            )

                            SettingsRow(
                                title: "Export Data",
                                subtitle: "Export your questions and settings",
                                icon: "square.and.arrow.up.fill",
                                action: { exportSettings() }
                            )

                            SettingsRow(
                                title: "Import Data",
                                subtitle: "Import questions from a file",
                                icon: "square.and.arrow.down.fill",
                                action: { showingImportDialog = true }
                            )
                        }

                        // Support Section
                        SettingsSection(title: "Support & Feedback", icon: "questionmark.circle.fill") {
                            SettingsRow(
                                title: "Send Feedback",
                                subtitle: "Help us improve Inkra",
                                icon: "heart.text.square.fill",
                                action: { showingFeedback = true }
                            )

                            SettingsRow(
                                title: "Diagnostics",
                                subtitle: "Technical information",
                                icon: "stethoscope",
                                action: { showingDiagnostics = true }
                            )
                        }

                        // Account Section
                        SettingsSection(title: "Account", icon: "person.fill") {
                            SettingsRow(
                                title: "Sign Out",
                                subtitle: "Sign out of your account",
                                icon: "arrow.backward.circle.fill",
                                isDestructive: true,
                                action: { signOut() }
                            )
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ColorTheme.primaryAccent)
                }
            }
        }
        // Sheet presentations
        .sheet(isPresented: $showingVoiceSettings) {
            VoiceSettingsView()
        }
        .sheet(isPresented: $showingDailyQuestions) {
            DailyQuestionsView()
        }
        .sheet(isPresented: $showingAccountSettings) {
            AccountSettingsView()
        }
        .fullScreenCover(isPresented: $showingAudioSettings) {
            AudioSettingsView()
        }
        .sheet(isPresented: $showingFeedback) {
            if #available(iOS 17.0, macOS 11.0, *) {
                FeedbackView()
            } else {
                Text("Feedback requires iOS 17 or later")
                    .padding()
            }
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView()
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Actions

    private func signOut() {
        // Auth disabled in V1 - no logout needed
        dismiss()
    }

    private func exportSettings() {
        do {
            let settingsData = SettingsExportData(
                dailyQuestions: questionsManager.questions,
                voiceSettings: VoiceSettingsExport(
                    selectedVoiceId: UserDefaults.standard.string(forKey: "selected_voice_id") ?? "Matthew",
                    speechRate: UserDefaults.standard.double(forKey: "default_speech_rate") != 0
                        ? UserDefaults.standard.double(forKey: "default_speech_rate")
                        : 1.0
                ),
                exportDate: Date(),
                version: "1.0"
            )

            let jsonData = try JSONEncoder().encode(settingsData)

            // Create temporary file for sharing
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("inkra-settings-\(DateFormatter.yyyyMMdd.string(from: Date())).json")

            try jsonData.write(to: tempURL)

            // Present share sheet
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityVC, animated: true)
            }

        } catch {
            showAlert(title: "Export Failed", message: "Failed to export settings: \(error.localizedDescription)")
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let data = try Data(contentsOf: url)
                let settingsData = try JSONDecoder().decode(SettingsExportData.self, from: data)

                // Import daily questions
                if !settingsData.dailyQuestions.isEmpty {
                    questionsManager.questions = settingsData.dailyQuestions
                    questionsManager.saveQuestions()
                }

                // Import voice settings
                UserDefaults.standard.set(settingsData.voiceSettings.selectedVoiceId, forKey: "selected_voice_id")
                UserDefaults.standard.set(settingsData.voiceSettings.speechRate, forKey: "default_speech_rate")

                showAlert(
                    title: "Import Successful",
                    message: "Imported \(settingsData.dailyQuestions.count) questions and voice settings."
                )

            } catch {
                showAlert(title: "Import Failed", message: "Failed to import settings: \(error.localizedDescription)")
            }

        case .failure(let error):
            showAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Supporting Views

@available(iOS 15.0, macOS 11.0, *)
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(ColorTheme.primaryAccent)
                    .frame(width: 24)

                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundColor(ColorTheme.starlightWhite)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 1) {
                content
            }
            .background(ColorTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ColorTheme.cardBorder, lineWidth: 0.5)
            )
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct SettingsRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isDestructive: Bool
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDestructive ? ColorTheme.error : ColorTheme.primaryAccent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.bodyText)
                        .foregroundColor(isDestructive ? ColorTheme.error : ColorTheme.starlightWhite)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Typography.metadata)
                            .foregroundColor(ColorTheme.moonstoneGrey)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ColorTheme.moonstoneGrey)
            }
            .padding(20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Export/Import Models

struct SettingsExportData: Codable {
    let dailyQuestions: [DailyQuestion]
    let voiceSettings: VoiceSettingsExport
    let exportDate: Date
    let version: String
}

struct VoiceSettingsExport: Codable {
    let selectedVoiceId: String
    let speechRate: Double
}

struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

#Preview {
    SettingsView()
}