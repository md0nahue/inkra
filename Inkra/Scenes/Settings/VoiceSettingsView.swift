import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct VoiceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVoiceId = "Matthew"
    @State private var speechRate = 1.0
    @State private var showVoiceSelection = false
    @StateObject private var voiceService = VoiceService.shared

    var body: some View {
        NavigationView {
            ZStack {
                ColorTheme.primaryBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "speaker.wave.3")
                                .font(.system(size: 48))
                                .foregroundColor(ColorTheme.primaryAccent)

                            Text("Voice Settings")
                                .font(Typography.screenTitle)
                                .foregroundColor(ColorTheme.starlightWhite)

                            Text("Configure your AI interview voice and speech settings")
                                .font(Typography.caption(14))
                                .foregroundColor(ColorTheme.moonstoneGrey)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Current Voice Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Current Voice")
                                .font(Typography.cardTitle)
                                .foregroundColor(ColorTheme.starlightWhite)

                            Button(action: { showVoiceSelection = true }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("AI Voice: \(selectedVoiceId)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(ColorTheme.primaryText)

                                        Text(String(format: "Speed: %.1fx", speechRate))
                                            .font(.caption)
                                            .foregroundColor(ColorTheme.secondaryText)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(ColorTheme.secondaryText)
                                }
                                .padding(20)
                                .cosmicLofiCard()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 24)

                        // Quick Speech Rate Adjustment
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Speech Rate")
                                .font(Typography.cardTitle)
                                .foregroundColor(ColorTheme.starlightWhite)

                            VStack(spacing: 16) {
                                HStack {
                                    Text("Slower")
                                        .font(.caption)
                                        .foregroundColor(ColorTheme.secondaryText)

                                    Spacer()

                                    Text(String(format: "%.1fx", speechRate))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(ColorTheme.primaryAccent)

                                    Spacer()

                                    Text("Faster")
                                        .font(.caption)
                                        .foregroundColor(ColorTheme.secondaryText)
                                }

                                Slider(value: $speechRate, in: 0.5...2.0, step: 0.1)
                                    .accentColor(ColorTheme.primaryAccent)
                            }
                            .padding(20)
                            .cosmicLofiCard()
                        }
                        .padding(.horizontal, 24)

                        // Save Button
                        Button(action: saveSettings) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Save Settings")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(ColorTheme.primaryAccent)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle("Voice Settings")
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
        .task {
            loadCurrentSettings()
        }
        .sheet(isPresented: $showVoiceSelection) {
            VoiceSelectionView(
                initialVoiceId: selectedVoiceId,
                initialSpeechRate: speechRate
            ) { voiceId, rate in
                selectedVoiceId = voiceId
                speechRate = rate
            }
        }
    }

    private func loadCurrentSettings() {
        // Load saved voice settings
        selectedVoiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? "Matthew"
        speechRate = UserDefaults.standard.double(forKey: "default_speech_rate")
        if speechRate <= 0 {
            speechRate = 1.0
        }
    }

    private func saveSettings() {
        // Save voice settings
        UserDefaults.standard.set(selectedVoiceId, forKey: "selected_voice_id")
        UserDefaults.standard.set(speechRate, forKey: "default_speech_rate")
        dismiss()
    }
}

#Preview {
    VoiceSettingsView()
}