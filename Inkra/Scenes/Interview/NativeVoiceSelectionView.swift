import SwiftUI
import AVFoundation

@available(iOS 15.0, macOS 11.0, *)
struct NativeVoiceSelectionView: View {
    @StateObject private var voiceService = NativeVoiceService.shared
    @State private var selectedVoice: AVSpeechSynthesisVoice?
    @State private var speechRate: Float = 0.5
    @State private var pitchMultiplier: Float = 1.0
    @State private var volume: Float = 1.0
    @State private var isPlaying = false
    @State private var playingVoiceId: String?
    @State private var searchText = ""
    @State private var selectedLanguage = "All Languages"
    @State private var selectedQuality = "All Qualities"

    @Environment(\.dismiss) private var dismiss

    let initialVoice: AVSpeechSynthesisVoice?
    let initialSpeechRate: Float?
    let onVoiceSelected: (AVSpeechSynthesisVoice, Float, Float, Float) -> Void

    private let previewText = "Hello! This is how I sound. I'm excited to help with your interview today."
    private let languages = ["All Languages", "English", "Spanish", "French", "German", "Italian", "Portuguese"]
    private let qualities = ["All Qualities", "Enhanced", "Premium", "Standard"]

    init(
        initialVoice: AVSpeechSynthesisVoice? = nil,
        initialSpeechRate: Float? = nil,
        onVoiceSelected: @escaping (AVSpeechSynthesisVoice, Float, Float, Float) -> Void
    ) {
        self.initialVoice = initialVoice
        self.initialSpeechRate = initialSpeechRate
        self.onVoiceSelected = onVoiceSelected
    }

    var body: some View {
        NavigationView {
            ZStack {
                ColorTheme.primaryBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Controls section
                    controlsSection
                        .padding()
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Voice list
                    ScrollView {
                        VStack(spacing: 16) {
                            headerSection
                            filtersSection
                            voiceListSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Native Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        voiceService.stopSpeaking()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if let voice = selectedVoice {
                            onVoiceSelected(voice, speechRate, pitchMultiplier, volume)
                        }
                        dismiss()
                    }
                    .disabled(selectedVoice == nil)
                }
            }
            .onAppear {
                setupInitialState()
            }
            .onDisappear {
                voiceService.stopSpeaking()
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 48))
                .foregroundColor(ColorTheme.primaryAccent)

            Text("Choose Your Native Voice")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Select from high-quality system voices with natural speech synthesis.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Speech Rate
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speech Rate")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(String(format: "%.1fx", speechRate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Slider(value: $speechRate, in: 0.25...1.0, step: 0.05) {
                    Text("Speech Rate")
                } minimumValueLabel: {
                    Text("Slow")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("Fast")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(ColorTheme.primaryAccent)
                .onChange(of: speechRate) { _ in
                    voiceService.setSpeechRate(speechRate)
                }
            }

            // Pitch
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pitch")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(String(format: "%.1fx", pitchMultiplier))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Slider(value: $pitchMultiplier, in: 0.5...2.0, step: 0.1) {
                    Text("Pitch")
                } minimumValueLabel: {
                    Text("Low")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("High")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(ColorTheme.primaryAccent)
                .onChange(of: pitchMultiplier) { _ in
                    voiceService.setPitchMultiplier(pitchMultiplier)
                }
            }

            // Volume
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(Int(volume * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Slider(value: $volume, in: 0.0...1.0, step: 0.1) {
                    Text("Volume")
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(ColorTheme.primaryAccent)
                .onChange(of: volume) { _ in
                    voiceService.setVolume(volume)
                }
            }

            // Test Current Voice Button
            Button(action: {
                testCurrentVoice()
            }) {
                HStack {
                    Image(systemName: voiceService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    Text(voiceService.isPlaying ? "Stop Test" : "Test Voice")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(ColorTheme.primaryAccent)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(selectedVoice == nil)
        }
    }

    private var filtersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search voices...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Language and Quality filters
            HStack(spacing: 12) {
                Menu {
                    ForEach(languages, id: \.self) { language in
                        Button(language) {
                            selectedLanguage = language
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedLanguage)
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTheme.cardBackground)
                    .cornerRadius(8)
                }

                Menu {
                    ForEach(qualities, id: \.self) { quality in
                        Button(quality) {
                            selectedQuality = quality
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedQuality)
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTheme.cardBackground)
                    .cornerRadius(8)
                }

                Spacer()
            }
        }
    }

    private var voiceListSection: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredVoices, id: \.identifier) { voice in
                NativeVoiceCardView(
                    voice: voice,
                    isSelected: selectedVoice?.identifier == voice.identifier,
                    isPlaying: playingVoiceId == voice.identifier,
                    onSelect: {
                        selectedVoice = voice
                        voiceService.setVoice(voice)
                    },
                    onPlayDemo: {
                        playDemo(for: voice)
                    },
                    onStop: {
                        voiceService.stopSpeaking()
                        playingVoiceId = nil
                    }
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredVoices: [AVSpeechSynthesisVoice] {
        var voices = voiceService.availableVoices

        // Filter by search text
        if !searchText.isEmpty {
            voices = voices.filter { voice in
                voice.name.localizedCaseInsensitiveContains(searchText) ||
                voiceService.getVoiceInfo(for: voice).languageName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by language
        if selectedLanguage != "All Languages" {
            let languageCode = languageCodeForName(selectedLanguage)
            voices = voices.filter { $0.language.hasPrefix(languageCode) }
        }

        // Filter by quality
        if selectedQuality != "All Qualities" {
            let quality = qualityForName(selectedQuality)
            voices = voices.filter { $0.quality == quality }
        }

        return voices
    }

    // MARK: - Helper Methods

    private func setupInitialState() {
        selectedVoice = initialVoice ?? voiceService.selectedVoice
        speechRate = initialSpeechRate ?? voiceService.speechRate
        pitchMultiplier = voiceService.pitchMultiplier
        volume = voiceService.volume

        // Set up voice service callbacks
        voiceService.onSpeechStarted = { utteranceId in
            if utteranceId == "preview" {
                isPlaying = true
            }
        }

        voiceService.onSpeechFinished = { utteranceId in
            if utteranceId == "preview" {
                isPlaying = false
                playingVoiceId = nil
            }
        }

        voiceService.onSpeechCancelled = { utteranceId in
            if utteranceId == "preview" {
                isPlaying = false
                playingVoiceId = nil
            }
        }
    }

    private func testCurrentVoice() {
        if voiceService.isPlaying {
            voiceService.stopSpeaking()
        } else if let voice = selectedVoice {
            playingVoiceId = voice.identifier
            voiceService.speak(text: previewText, utteranceId: "preview")
        }
    }

    private func playDemo(for voice: AVSpeechSynthesisVoice) {
        voiceService.stopSpeaking()
        playingVoiceId = voice.identifier

        let previousVoice = voiceService.selectedVoice
        voiceService.setVoice(voice)
        voiceService.speak(text: previewText, utteranceId: "preview")

        // Restore previous voice after demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if let previous = previousVoice {
                voiceService.setVoice(previous)
            }
        }
    }

    private func languageCodeForName(_ name: String) -> String {
        switch name {
        case "English": return "en"
        case "Spanish": return "es"
        case "French": return "fr"
        case "German": return "de"
        case "Italian": return "it"
        case "Portuguese": return "pt"
        default: return ""
        }
    }

    private func qualityForName(_ name: String) -> AVSpeechSynthesisVoiceQuality {
        switch name {
        case "Enhanced": return .enhanced
        case "Premium": return .premium
        case "Standard": return .default
        default: return .default
        }
    }
}

// MARK: - Native Voice Card View

struct NativeVoiceCardView: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPlayDemo: () -> Void
    let onStop: () -> Void

    private var voiceInfo: VoiceInfo {
        return NativeVoiceService.shared.getVoiceInfo(for: voice)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Voice info section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(voice.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Spacer()

                    // Quality badge
                    Text(voiceInfo.qualityDescription)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(qualityColor.opacity(0.2))
                        .foregroundColor(qualityColor)
                        .cornerRadius(4)
                }

                HStack(spacing: 4) {
                    Text(voiceInfo.languageName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(voiceInfo.genderDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Play button
            Button(action: {
                if isPlaying {
                    onStop()
                } else {
                    onPlayDemo()
                }
            }) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(ColorTheme.primaryAccent)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(
            isSelected ? ColorTheme.primaryAccent.opacity(0.1) : ColorTheme.cardBackground
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? ColorTheme.primaryAccent : Color.clear,
                    lineWidth: 2
                )
        )
        .onTapGesture {
            onSelect()
        }
    }

    private var qualityColor: Color {
        switch voice.quality {
        case .enhanced:
            return .green
        case .premium:
            return .purple
        case .default:
            return .blue
        @unknown default:
            return .gray
        }
    }
}

#Preview {
    NativeVoiceSelectionView { voice, rate, pitch, volume in
        print("Selected: \(voice.name) at \(rate)x rate, \(pitch)x pitch, \(Int(volume*100))% volume")
    }
}