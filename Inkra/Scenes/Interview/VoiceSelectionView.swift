import SwiftUI
import AVFoundation

@available(iOS 15.0, macOS 11.0, *)
struct VoiceSelectionView: View {
    @State private var audioPlayer = AVPlayer()
    @State private var voices: [PollyVoice] = []
    @State private var selectedVoiceId = "Joanna"
    @State private var speechRate = 1.0
    @State private var isLoading = true
    @State private var playingVoiceId: String?
    @StateObject private var voiceService = VoiceService.shared
    @Environment(\.dismiss) private var dismiss
    
    let initialVoiceId: String?
    let initialSpeechRate: Double?
    let onVoiceSelected: (String, Double) -> Void
    
    init(initialVoiceId: String? = nil, initialSpeechRate: Double? = nil, onVoiceSelected: @escaping (String, Double) -> Void) {
        self.initialVoiceId = initialVoiceId
        self.initialSpeechRate = initialSpeechRate
        self.onVoiceSelected = onVoiceSelected
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ColorTheme.primaryBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        loadingView
                            .frame(minHeight: 400)
                    } else {
                        // Speech rate and confirm button at top
                        VStack(spacing: 16) {
                            speechRateSection
                            confirmButton
                        }
                        .padding()
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        ScrollView {
                            VStack(spacing: 24) {
                                headerSection
                                voiceSelectionSection
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Choose Your Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadVoices()
            }
            .onDisappear {
                stopAllAudio()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading voices...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(ColorTheme.primaryAccent)
            
            Text("Select Your Interview Voice")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Choose a voice that feels right for your personal interview experience.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var voiceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Voices")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(voices, id: \.id) { voice in
                    VoiceCardView(
                        voice: voice,
                        isSelected: selectedVoiceId == voice.id,
                        isPlaying: playingVoiceId == voice.id,
                        speechRate: speechRate,
                        onSelect: {
                            selectedVoiceId = voice.id
                        },
                        onPlayDemo: {
                            playDemo(for: voice)
                        },
                        onStop: {
                            stopAllAudio()
                        }
                    )
                }
            }
        }
    }
    
    private var speechRateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Speech Rate")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(format: "%.1fx", speechRate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: Binding(
                get: { speechRate },
                set: { speechRate = $0 }
            ), in: 0.5...2.0, step: 0.1)
            .accentColor(ColorTheme.primaryAccent)
            
            HStack {
                Text("Slower")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Faster")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var confirmButton: some View {
        Button(action: {
            // Save speech rate as global default for future use
            UserDefaults.standard.set(speechRate, forKey: "default_speech_rate")
            onVoiceSelected(selectedVoiceId, speechRate)
            dismiss()
        }) {
            HStack {
                Image(systemName: "checkmark.circle")
                Text("Use This Voice")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(ColorTheme.primaryAccent)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
    }
    
    private func loadVoices() async {
        await MainActor.run {
            // Use cached voices from the service
            if !voiceService.cachedVoices.isEmpty {
                self.voices = voiceService.cachedVoices
                self.selectedVoiceId = initialVoiceId ?? voices.first?.id ?? "Joanna"
                // If no initial speech rate provided, check for saved global default, otherwise use 1.0
                if let initialRate = initialSpeechRate {
                    self.speechRate = initialRate
                } else {
                    let savedRate = UserDefaults.standard.double(forKey: "default_speech_rate")
                    self.speechRate = savedRate > 0 ? savedRate : 1.0
                }
                self.isLoading = false
            } else {
                // If no cached voices, fetch them
                Task {
                    await voiceService.fetchAndCacheVoices()
                    await MainActor.run {
                        self.voices = voiceService.cachedVoices
                        self.selectedVoiceId = initialVoiceId ?? voices.first?.id ?? "Joanna"
                        // If no initial speech rate provided, check for saved global default, otherwise use 1.0
                        if let initialRate = initialSpeechRate {
                            self.speechRate = initialRate
                        } else {
                            let savedRate = UserDefaults.standard.double(forKey: "default_speech_rate")
                            self.speechRate = savedRate > 0 ? savedRate : 1.0
                        }
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func playDemo(for voice: PollyVoice) {
        // Stop any currently playing audio first
        stopAllAudio()
        
        // Set playing state immediately for better UI responsiveness
        playingVoiceId = voice.id
        
        // First try to play from bundled resources
        let fileName = "\(voice.id.lowercased())_demo"
        if let bundledURL = Bundle.main.url(forResource: fileName, withExtension: "mp3") {
            print("Playing bundled demo for \(voice.name)")
            playUrl(bundledURL, for: voice.id)
        } else if let url = URL(string: voice.demoUrl ?? "") {
            // Fallback to remote URL if bundled file not found
            print("Playing remote demo for \(voice.name)")
            playUrl(url, for: voice.id)
        } else {
            print("No demo available for voice: \(voice.name)")
            playingVoiceId = nil
        }
    }

    // Helper to avoid code duplication
    private func playUrl(_ url: URL, for voiceId: String) {
        playingVoiceId = voiceId
        let playerItem = AVPlayerItem(url: url)
        
        // Set up observer for when audio finishes playing
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            playingVoiceId = nil
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        }
        
        audioPlayer.replaceCurrentItem(with: playerItem)
        
        // Start playback first
        audioPlayer.play()
        
        // Set the playback rate AFTER starting playback to ensure it applies
        audioPlayer.rate = Float(speechRate)
        
        // Fallback auto-stop after a reasonable duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if playingVoiceId == voiceId {
                playingVoiceId = nil
            }
        }
    }
    
    private func stopAllAudio() {
        audioPlayer.pause()
        playingVoiceId = nil
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct VoiceCardView: View {
    let voice: PollyVoice
    let isSelected: Bool
    let isPlaying: Bool
    let speechRate: Double
    let onSelect: () -> Void
    let onPlayDemo: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Text(voice.neural ? "Neural" : "Standard")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(accentText(for: voice.languageCode))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if voice.neural {
                    Text("AI")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ColorTheme.primaryAccent.opacity(0.2))
                        .foregroundColor(ColorTheme.primaryAccent)
                        .cornerRadius(4)
                }
            }
            
            Button(action: {
                if isPlaying {
                    // Stop the audio if currently playing
                    onStop()
                } else {
                    // Start playing demo
                    onPlayDemo()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text(isPlaying ? "Stop" : "Listen")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(ColorTheme.primaryAccent)
                .cornerRadius(10)
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
    
    private func accentText(for languageCode: String) -> String {
        switch languageCode {
        case "en-US": return "American"
        case "en-GB": return "British"
        case "en-AU": return "Australian"
        case "en-NZ": return "Kiwi"
        case "en-CA": return "Canadian"
        case "en-IE": return "Irish"
        case "en-ZA": return "South African"
        case "en-IN": return "Indian"
        default: return "English"
        }
    }
}

#Preview {
    VoiceSelectionView { voiceId, rate in
        print("Selected voice: \(voiceId) at \(rate)% rate")
    }
}