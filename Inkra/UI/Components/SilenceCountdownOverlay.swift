import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct SilenceCountdownOverlay: View {
    @ObservedObject var audioRecorder: AudioRecorder
    
    var body: some View {
        if audioRecorder.showingSilenceCountdown {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Countdown circle
                    ZStack {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.3),
                                lineWidth: 4
                            )
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(audioRecorder.silenceCountdown) / 3.0)
                            .stroke(
                                LinearGradient(
                                    colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(audioRecorder.silenceCountdown))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Moving to next question")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Speak now to continue with this question")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.7),
                                    Color.black.opacity(0.5)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .animation(.easeInOut(duration: 0.3), value: audioRecorder.showingSilenceCountdown)
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct CompactSilenceCountdownView: View {
    let countdown: Double
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                // Countdown indicator
                ZStack {
                    Circle()
                        .stroke(ColorTheme.warning.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(countdown) / 3.0)
                        .stroke(ColorTheme.warning, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(countdown))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.warning)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moving to next question")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTheme.warning)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                    
                    Text("Speak to continue with this question")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTheme.warning.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorTheme.warning.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // Full overlay preview
        ZStack {
            Rectangle()
                .fill(Color.blue)
                .frame(height: 300)
            
            SilenceCountdownOverlay(audioRecorder: {
                let recorder = AudioRecorder()
                recorder.showingSilenceCountdown = true
                recorder.silenceCountdown = 3
                return recorder
            }())
        }
        
        // Compact view preview
        CompactSilenceCountdownView(countdown: 2.5, isVisible: true)
            .padding()
    }
}