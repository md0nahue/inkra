import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct InterviewLoadingView: View {
    @State private var animationAmount = 0.0
    @State private var textOpacity = 0.0
    @State private var showSecondaryText = false
    @State private var currentQuoteIndex = 0
    @State private var quoteOpacity = 0.0
    
    struct Quote {
        let text: String
        let author: String
    }
    
    let inspirationalQuotes = [
        Quote(text: "Life is either a daring adventure or nothing at all.", author: "Helen Keller"),
        Quote(text: "Vulnerability is not weakness; it's our greatest measure of courage.", author: "Brené Brown"),
        Quote(text: "To be yourself in a world that is constantly trying to make you something else is the greatest accomplishment.", author: "Ralph Waldo Emerson"),
        Quote(text: "The privilege of a lifetime is to become who you truly are.", author: "Carl Jung"),
        Quote(text: "Do one thing every day that scares you.", author: "Eleanor Roosevelt"),
        Quote(text: "What happens when people open their hearts? They get better.", author: "Haruki Murakami"),
        Quote(text: "Only those who will risk going too far can possibly find out how far one can go.", author: "T.S. Eliot"),
        Quote(text: "Be yourself; everyone else is already taken.", author: "Oscar Wilde"),
        Quote(text: "The ability to be in the present moment is a major component of mental wellness.", author: "Abraham Maslow"),
        Quote(text: "Faith is taking the first step even when you don't see the whole staircase.", author: "Martin Luther King, Jr.")
    ].shuffled()
    
    var body: some View {
        ZStack {
            // Background
            ColorTheme.primaryBackground
                .ignoresSafeArea()
            
            // Animated gradient background
            LinearGradient(
                colors: [
                    ColorTheme.primaryAccent.opacity(0.1),
                    ColorTheme.secondaryAccent.opacity(0.1),
                    ColorTheme.tertiaryAccent.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .hueRotation(.degrees(animationAmount))
            .animation(
                Animation.easeInOut(duration: 3)
                    .repeatForever(autoreverses: true),
                value: animationAmount
            )
            
            VStack(spacing: 48) {
                // Main loading animation - custom spinning circles
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(ColorTheme.primaryAccent, lineWidth: 4)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(animationAmount * 2))
                    
                    Circle()
                        .trim(from: 0, to: 0.6)
                        .stroke(ColorTheme.secondaryAccent.opacity(0.6), lineWidth: 3)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-animationAmount * 1.5))
                    
                    Circle()
                        .trim(from: 0, to: 0.4)
                        .stroke(ColorTheme.tertiaryAccent.opacity(0.4), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(animationAmount * 2.5))
                }
                
                VStack(spacing: 16) {
                    Text("Preparing Your Interview")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ColorTheme.primaryText, ColorTheme.primaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(textOpacity)
                    
                    if showSecondaryText {
                        Text("Crafting personalized questions just for you...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ColorTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Inspirational quote display
                    if currentQuoteIndex < inspirationalQuotes.count {
                        VStack(spacing: 8) {
                            Text(inspirationalQuotes[currentQuoteIndex].text)
                                .font(Font.system(size: 14, weight: .medium, design: .rounded).italic())
                                .foregroundColor(ColorTheme.secondaryText.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .opacity(quoteOpacity)
                            
                            Text("— \(inspirationalQuotes[currentQuoteIndex].author)")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(ColorTheme.secondaryText.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .opacity(quoteOpacity)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            animationAmount = 360
            
            withAnimation(.easeIn(duration: 0.8)) {
                textOpacity = 1
            }
            
            withAnimation(.easeIn(duration: 0.8).delay(0.5)) {
                showSecondaryText = true
            }
            
            // Start quote rotation
            withAnimation(.easeIn(duration: 0.8).delay(1.0)) {
                quoteOpacity = 1
            }
            
            // Cycle through quotes every 16 seconds
            Timer.scheduledTimer(withTimeInterval: 16.0, repeats: true) { timer in
                withAnimation(.easeOut(duration: 0.3)) {
                    quoteOpacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if currentQuoteIndex < inspirationalQuotes.count - 1 {
                        currentQuoteIndex += 1
                    } else {
                        currentQuoteIndex = 0
                    }
                    
                    withAnimation(.easeIn(duration: 0.3)) {
                        quoteOpacity = 1
                    }
                }
            }
        }
    }
}

// Alternative modern loading view with different animation
@available(iOS 15.0, macOS 11.0, *)
struct AlternativeLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ColorTheme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Pulsing bars animation
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTheme.primaryAccent)
                            .frame(width: 6, height: 40)
                            .scaleEffect(y: isAnimating ? CGFloat.random(in: 0.3...1.0) : 0.3)
                            .animation(
                                Animation.easeInOut(duration: 0.8)
                                    .repeatForever()
                                    .delay(Double(index) * 0.1),
                                value: isAnimating
                            )
                    }
                }
                .frame(width: 100, height: 100)
                
                VStack(spacing: 12) {
                    Text("Loading Interview")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ColorTheme.primaryText)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(ColorTheme.primaryAccent)
                                .frame(width: 8, height: 8)
                                .scaleEffect(isAnimating ? 1 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    InterviewLoadingView()
}

#Preview("Alternative") {
    AlternativeLoadingView()
}