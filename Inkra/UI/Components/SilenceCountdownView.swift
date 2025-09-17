import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct SilenceCountdownView: View {
    let countdown: Int
    let isVisible: Bool
    @State private var scale: Double = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        if isVisible && countdown > 0 {
            VStack(spacing: 16) {
                // Main countdown circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 120, height: 120)
                    
                    // Animated progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(4 - countdown) / 3.0)
                        .stroke(
                            LinearGradient(
                                colors: [ColorTheme.primaryAccent, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: countdown)
                    
                    // Countdown number
                    Text("\(countdown)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ColorTheme.primaryAccent, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
                .scaleEffect(isVisible ? 1.0 : 0.8)
                .opacity(isVisible ? 1.0 : 0.0)
                
                // Status text
                Text("Next question in...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(isVisible ? 1.0 : 0.0)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.8),
                                Color.black.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: ColorTheme.primaryAccent.opacity(0.3),
                radius: 20,
                x: 0,
                y: 10
            )
            .transition(
                .asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                )
            )
            .onChange(of: countdown) { newValue in
                // Animate the number change
                withAnimation(.easeOut(duration: 0.1)) {
                    scale = newValue > 0 ? 1.2 : 1.0
                    opacity = 0.8
                }
                
                // Return to normal
                withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
                    scale = 1.0
                    opacity = 1.0
                }
                
                // Add haptic feedback for each countdown tick
                #if os(iOS)
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                #endif
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}


#Preview {
    VStack(spacing: 40) {
        SilenceCountdownView(countdown: 3, isVisible: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}