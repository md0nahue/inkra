import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct AudioPlaybackView: View {
    let audioSegmentId: Int
    let projectId: Int
    
    @StateObject private var audioPlayback = AudioPlaybackService.shared
    @StateObject private var audioService = AudioService()
    @State private var playbackURL: URL?
    @State private var isLoadingURL = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Play/Pause Button
                Button(action: togglePlayback) {
                    Image(systemName: playbackButtonIcon)
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(playbackButtonColor)
                        .clipShape(Circle())
                }
                .disabled(isLoadingURL || audioPlayback.isLoading)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Progress Bar
                    let progress = audioPlayback.duration > 0 ? audioPlayback.currentTime / audioPlayback.duration : 0
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(height: 4)
                    
                    // Time Display
                    HStack {
                        Text(formatTime(audioPlayback.currentTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if audioPlayback.duration > 0 {
                            Text(formatTime(audioPlayback.duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Speed Control Buttons
                HStack(spacing: 4) {
                    ForEach([1.0, 1.5, 2.0], id: \.self) { speed in
                        Button(action: {
                            audioPlayback.setPlaybackRate(Float(speed))
                        }) {
                            Text("\(speed, specifier: "%.1f")x")
                                .font(.caption)
                                .foregroundColor(audioPlayback.playbackRate == Float(speed) ? .white : .blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(audioPlayback.playbackRate == Float(speed) ? .blue : .clear)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.blue, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            
            if let errorMessage = errorMessage ?? audioPlayback.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .task {
            await loadPlaybackURL()
        }
    }
    
    private var playbackButtonIcon: String {
        if isLoadingURL || audioPlayback.isLoading {
            return "hourglass"
        } else if isCurrentlyPlaying {
            return "pause.fill"
        } else {
            return "play.fill"
        }
    }
    
    private var playbackButtonColor: Color {
        if isLoadingURL || audioPlayback.isLoading {
            return .gray
        } else {
            return .blue
        }
    }
    
    private var isCurrentlyPlaying: Bool {
        audioPlayback.isCurrentSegment(String(audioSegmentId)) && audioPlayback.isPlaying
    }
    
    private func togglePlayback() {
        if isCurrentlyPlaying {
            audioPlayback.pausePlayback()
        } else if audioPlayback.isCurrentSegment(String(audioSegmentId)) {
            audioPlayback.resumePlayback()
        } else {
            // Start new playback
            if let url = playbackURL {
                Task {
                    await audioPlayback.playAudio(from: url, audioSegmentId: String(audioSegmentId))
                }
            }
        }
    }
    
    private func loadPlaybackURL() async {
        guard playbackURL == nil else { return }
        
        isLoadingURL = true
        errorMessage = nil
        
        do {
            let response = try await audioService.getPlaybackURL(projectId: projectId, audioSegmentId: audioSegmentId)
            if let url = URL(string: response.playbackUrl) {
                playbackURL = url
            } else {
                errorMessage = "Invalid playback URL"
            }
        } catch {
            errorMessage = "Failed to load audio: \(error.localizedDescription)"
        }
        
        isLoadingURL = false
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
}

#Preview {
    AudioPlaybackView(
        audioSegmentId: 1,
        projectId: 1
    )
    .padding()
}