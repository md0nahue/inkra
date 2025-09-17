import SwiftUI
import AVFoundation

@available(iOS 15.0, macOS 11.0, *)
struct PostInterviewLoadingView: View {
    
    // Customizable message
    var title: String = "Preparing Your Summary"
    var message: String = ""
    
    init(title: String = "Preparing Your Summary", message: String = "", onError: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.onError = onError
        self.onDismiss = onDismiss
    }
    
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var pulseScale: CGFloat = 1
    @State private var messageIndex = 0
    @State private var messageOpacity: Double = 0
    @State private var particlesVisible = false
    @State private var vibePulse: CGFloat = 0.8
    @State private var readyToTransition = false
    @State private var currentBackgroundIndex = 0
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var backgroundTimer: Timer?
    @State private var quoteTimer: Timer?
    @State private var progressMessageIndex = 0
    @State private var progressOpacity: Double = 0
    
    // Callback handlers for error recovery
    var onError: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    let backgroundImages = [
        "dawn-walker-eye-level-atmospheric",
        "mountain-sage-triumphant-landscape", 
        "window-gazer-atmospheric-mood",
        "atmospheric-background-1",
        "atmospheric-background-2",
        "atmospheric-background-3",
        "city-woman",
        "lakeside-silhouette",
        "forest-silhouette"
    ]
    
    struct Quote {
        let text: String
        let author: String
    }
    
    // Post-interview specific quotes about reflection and completion
    let reflectionQuotes = [
        // Reflection and Self-Discovery
        Quote(text: "The unexamined life is not worth living.", author: "Socrates"),
        Quote(text: "We do not learn from experience... we learn from reflecting on experience.", author: "John Dewey"),
        Quote(text: "Your life is your story. Write well. Edit often.", author: "Susan Statham"),
        Quote(text: "The real voyage of discovery consists not in seeking new landscapes, but in having new eyes.", author: "Marcel Proust"),
        Quote(text: "Life can only be understood backwards; but it must be lived forwards.", author: "Søren Kierkegaard"),
        Quote(text: "The most important conversations you'll ever have are the ones you'll have with yourself.", author: "David Goggins"),
        
        // Growth and Learning
        Quote(text: "What we plant in the soil of contemplation, we shall reap in the harvest of action.", author: "Meister Eckhart"),
        Quote(text: "In any given moment we have two options: to step forward into growth or to step back into safety.", author: "Abraham Maslow"),
        Quote(text: "The only way to make sense out of change is to plunge into it, move with it, and join the dance.", author: "Alan Watts"),
        Quote(text: "Every experience, no matter how bad it seems, holds within it a blessing of some kind. The goal is to find it.", author: "Buddha"),
        Quote(text: "Growth begins at the end of your comfort zone.", author: "Neale Donald Walsch"),
        
        // Completion and Achievement
        Quote(text: "What we plant in the soil of contemplation, we shall reap in the harvest of action.", author: "Meister Eckhart"),
        Quote(text: "The way to get started is to quit talking and begin doing.", author: "Walt Disney"),
        Quote(text: "A journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
        Quote(text: "Well done is better than well said.", author: "Benjamin Franklin"),
        Quote(text: "Success is not final, failure is not fatal: it is the courage to continue that counts.", author: "Winston Churchill"),
        
        // Wisdom and Insight
        Quote(text: "The quieter you become, the more you are able to hear.", author: "Rumi"),
        Quote(text: "Yesterday I was clever, so I wanted to change the world. Today I am wise, so I am changing myself.", author: "Rumi"),
        Quote(text: "The cave you fear to enter holds the treasure you seek.", author: "Joseph Campbell"),
        Quote(text: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", author: "Aristotle"),
        Quote(text: "Knowing others is wisdom, knowing yourself is enlightenment.", author: "Lao Tzu"),
        
        // Moving Forward
        Quote(text: "What lies behind us and what lies before us are tiny matters compared to what lies within us.", author: "Ralph Waldo Emerson"),
        Quote(text: "The best time to plant a tree was 20 years ago. The second best time is now.", author: "Chinese Proverb"),
        Quote(text: "Don't watch the clock; do what it does. Keep going.", author: "Sam Levenson"),
        Quote(text: "It is during our darkest moments that we must focus to see the light.", author: "Aristotle"),
        Quote(text: "The future belongs to those who believe in the beauty of their dreams.", author: "Eleanor Roosevelt")
    ].shuffled()
    
    // Progress messages that cycle through
    let progressMessages = [
        "Processing your responses...",
        "Analyzing your insights...",
        "Finalizing your interview...",
        "Creating your summary...",
        "Preparing your content...",
        "Getting everything ready...",
        "Almost there..."
    ]
    
    var body: some View {
        ZStack {
            // FULL SCREEN BACKGROUND - MUST COME FIRST
            Color.black
                .ignoresSafeArea()
            
            if hasError {
                // Error state - stable background
                Color.black
                    .ignoresSafeArea()
                errorView
            } else {
                // Loading state - dynamic background
                backgroundGradient
                    .ignoresSafeArea()
                
                // Animated particles
                if particlesVisible {
                    ParticleEffectView()
                        .ignoresSafeArea()
                        .opacity(0.3)
                }
                
                // Content - centered properly
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Animated Logo/Brand Section
                    brandingSection
                    
                    // Progress message
                    progressSection
                    
                    // Dynamic loading animation
                    loadingAnimation
                    
                    // Motivational quotes
                    quotesSection
                        .frame(maxWidth: UIScreen.main.bounds.width - 80)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            cleanupTimers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ServerError"))) { notification in
            handleServerError(notification)
        }
    }
    
    private var backgroundGradient: some View {
        ZStack {
            // Try to load background image with fallback
            if let uiImage = UIImage(named: backgroundImages[currentBackgroundIndex]) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
                    .transition(.opacity)
            } else {
                // Fallback gradient if image not found
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color.black
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Dark overlay for text readability
            Color.black.opacity(0.5)
            
            // Subtle animated overlay
            RadialGradient(
                gradient: Gradient(colors: [
                    ColorTheme.primaryAccent.opacity(0.15),
                    Color.clear
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .scaleEffect(pulseScale)
            .animation(
                Animation.easeInOut(duration: 4)
                    .repeatForever(autoreverses: true),
                value: pulseScale
            )
        }
    }
    
    private var brandingSection: some View {
        VStack(spacing: 20) {
            // App logo or icon - FIXED POSITIONING TO PREVENT GOING OFF SCREEN
            ZStack {
                // Glowing effect - REDUCED SIZE
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ColorTheme.primaryAccent.opacity(0.4),
                                ColorTheme.primaryAccent.opacity(0.1),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 15,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(min(vibePulse, 1.1))
                    .blur(radius: 15)
                
                // Main logo - CONSTRAINED SIZE
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorTheme.primaryAccent,
                                    ColorTheme.secondaryAccent,
                                    ColorTheme.tertiaryAccent
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(ringRotation))
                    
                    Image("octopus-transparent-background")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .colorMultiply(.white)
                }
                .scaleEffect(min(logoScale, 1.0))
                .opacity(logoOpacity)
            }
            .frame(maxWidth: 140, maxHeight: 140)
            .clipped()
            
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .white,
                            ColorTheme.primaryAccent.opacity(0.9)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(logoOpacity)
                .shadow(color: ColorTheme.primaryAccent.opacity(0.5), radius: 8, x: 0, y: 4)
            
            // Custom message if provided
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .opacity(logoOpacity)
                    .padding(.top, 8)
            }
        }
        .padding(.top, 20)
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            if progressMessageIndex < progressMessages.count {
                Text(progressMessages[progressMessageIndex])
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(ColorTheme.primaryAccent.opacity(0.9))
                    .opacity(progressOpacity)
                    .animation(.easeInOut(duration: 0.5), value: progressOpacity)
            }
        }
        .frame(minHeight: 30)
    }
    
    private var loadingAnimation: some View {
        ZStack {
            // Outer rotating rings - CONSTRAINED SIZE
            ForEach(0..<3) { index in
                Circle()
                    .trim(from: 0, to: CGFloat(0.7 - Double(index) * 0.2))
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ColorTheme.primaryAccent.opacity(0.8 - Double(index) * 0.2),
                                ColorTheme.secondaryAccent.opacity(0.6 - Double(index) * 0.2),
                                ColorTheme.tertiaryAccent.opacity(0.4 - Double(index) * 0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: CGFloat(3 - index), lineCap: .round)
                    )
                    .frame(width: CGFloat(80 + index * 20), height: CGFloat(80 + index * 20))
                    .rotationEffect(.degrees(ringRotation * Double(index % 2 == 0 ? 1 : -1) * (1 + Double(index) * 0.5)))
            }
            
            // Center pulsing dots
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorTheme.primaryAccent,
                                    ColorTheme.secondaryAccent
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseScale)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: pulseScale
                        )
                }
            }
        }
        .frame(maxWidth: 140, maxHeight: 140)
        .clipped()
    }
    
    private var quotesSection: some View {
        VStack(spacing: 16) {
            if messageIndex < reflectionQuotes.count {
                VStack(spacing: 8) {
                    Text(reflectionQuotes[messageIndex].text)
                        .font(Font.system(size: 16, weight: .medium, design: .rounded).italic())
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(messageOpacity)
                        .animation(.easeInOut(duration: 0.5), value: messageOpacity)
                    
                    Text("— \(reflectionQuotes[messageIndex].author)")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .opacity(messageOpacity)
                        .animation(.easeInOut(duration: 0.5), value: messageOpacity)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 100)
    }
    
    // Error view for graceful error handling
    private var errorView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Friendly error icon with same style as loading
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.4),
                                Color.orange.opacity(0.1),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 15,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 15)
                
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange,
                                    Color.red,
                                    Color.pink
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                }
            }
            
            VStack(spacing: 16) {
                Text("Processing Issue")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .white,
                                Color.orange.opacity(0.9)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .shadow(color: Color.orange.opacity(0.5), radius: 8, x: 0, y: 4)
                
                Text(errorMessage.isEmpty ? "We encountered an issue while processing your interview. Your responses have been saved." : errorMessage)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    resetToLoadingState()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                
                Button(action: {
                    onDismiss?()
                }) {
                    HStack {
                        Image(systemName: "house")
                        Text("Go to Project Overview")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
    }
    
    private func startAnimations() {
        // Set random starting background
        currentBackgroundIndex = Int.random(in: 0..<backgroundImages.count)
        
        // Logo entrance
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)) {
            logoScale = 1
            logoOpacity = 1
        }
        
        // Start ring rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        
        // Start pulse
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
            vibePulse = 1.2
        }
        
        // Show particles
        withAnimation(.easeIn(duration: 1).delay(0.5)) {
            particlesVisible = true
        }
        
        // Initial progress message
        withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
            progressOpacity = 1
        }
        
        // Auto-dismiss after showing meaningful loading content (3-5 seconds)
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            guard !hasError else { return }
            onDismiss?()
        }
        
        // Cycle through progress messages faster
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            guard !hasError else { 
                timer.invalidate()
                return 
            }
            
            withAnimation(.easeOut(duration: 0.3)) {
                progressOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard !hasError else { return }
                
                if progressMessageIndex < progressMessages.count - 1 {
                    progressMessageIndex += 1
                    
                    withAnimation(.easeIn(duration: 0.3)) {
                        progressOpacity = 1
                    }
                } else {
                    progressMessageIndex = 0
                    withAnimation(.easeIn(duration: 0.3)) {
                        progressOpacity = 1
                    }
                }
            }
        }
        
        // Cycle through quotes and backgrounds
        quoteTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { timer in
            guard !hasError else { 
                timer.invalidate()
                return 
            }
            
            withAnimation(.easeOut(duration: 0.5)) {
                messageOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !hasError else { return }
                
                if messageIndex < reflectionQuotes.count - 1 {
                    messageIndex += 1
                    
                    withAnimation(.easeIn(duration: 0.5)) {
                        messageOpacity = 1
                    }
                } else {
                    messageIndex = 0
                    withAnimation(.easeIn(duration: 0.5)) {
                        messageOpacity = 1
                    }
                }
            }
        }
        
        // Separate background timer for stability with proper random selection
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { timer in
            guard !hasError else { 
                timer.invalidate()
                return 
            }
            
            // Get next random index that's different from current
            var nextIndex = Int.random(in: 0..<backgroundImages.count)
            while nextIndex == currentBackgroundIndex && backgroundImages.count > 1 {
                nextIndex = Int.random(in: 0..<backgroundImages.count)
            }
            
            withAnimation(.easeInOut(duration: 2.0)) {
                currentBackgroundIndex = nextIndex
            }
        }
        
        // Initial message - show immediately
        withAnimation(.easeIn(duration: 0.3).delay(0.8)) {
            messageOpacity = 1
        }
    }
    
    private func cleanupTimers() {
        quoteTimer?.invalidate()
        quoteTimer = nil
        backgroundTimer?.invalidate()
        backgroundTimer = nil
    }
    
    private func handleServerError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let statusCode = userInfo["statusCode"] as? Int else { return }
        
        var message = ""
        
        switch statusCode {
        case 500...599:
            message = "Our servers are having a temporary issue processing your interview. Your responses are saved."
        case 404:
            message = "The interview data was not found. Let's return to your projects."
        case 400...499:
            message = "There was an issue processing your interview. Let's try again."
        default:
            message = "We encountered an unexpected issue. Your responses have been saved."
        }
        
        showError(message: message)
    }
    
    private func showError(message: String) {
        cleanupTimers()
        
        withAnimation(.easeInOut(duration: 0.8)) {
            hasError = true
            errorMessage = message
        }
        
        onError?()
    }
    
    private func resetToLoadingState() {
        withAnimation(.easeInOut(duration: 0.8)) {
            hasError = false
            errorMessage = ""
            messageOpacity = 0
            progressOpacity = 0
            logoOpacity = 0
            particlesVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            startAnimations()
        }
    }
}

#Preview {
    PostInterviewLoadingView()
}