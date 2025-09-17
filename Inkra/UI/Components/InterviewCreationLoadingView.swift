import SwiftUI
import AVFoundation

@available(iOS 15.0, macOS 11.0, *)
struct InterviewCreationLoadingView: View {
    
    // Customizable message
    var title: String = "Inkra"
    var message: String = ""
    
    init(title: String = "Inkra", message: String = "", onError: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
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
    @State private var selectedBackgroundImage: String = ""
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var quoteTimer: Timer?
    
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
    
    let inspirationalQuotes = [
        // Taking Chances and Risks
        Quote(text: "Life is either a daring adventure or nothing at all.", author: "Helen Keller"),
        Quote(text: "Only those who will risk going too far can possibly find out how far one can go.", author: "T.S. Eliot"),
        Quote(text: "If you don't risk anything, you risk even more.", author: "Erica Jong"),
        Quote(text: "Take a chance! All life is a chance. The man who goes farthest is generally the one who is willing to do and dare.", author: "Dale Carnegie"),
        Quote(text: "Do one thing every day that scares you.", author: "Eleanor Roosevelt"),
        Quote(text: "To dare is to lose one's footing momentarily. To not dare is to lose oneself.", author: "Søren Kierkegaard"),
        Quote(text: "When you take risks you learn that there will be times when you succeed and there will be times when you fail, and both are equally important.", author: "Ellen DeGeneres"),
        Quote(text: "A ship in port is safe, but that's not what ships are built for.", author: "John A. Shedd"),
        Quote(text: "Never let the odds keep you from doing what you know in your heart you were meant to do.", author: "H. Jackson Brown, Jr."),
        Quote(text: "The biggest risk is not taking any risk... In a world that is changing really quickly, the only strategy that is guaranteed to fail is not taking risks.", author: "Mark Zuckerberg"),
        Quote(text: "Life shrinks or expands in proportion to one's courage.", author: "Anais Nin"),
        Quote(text: "Progress always involves risks. You can't steal second base and keep your foot on first.", author: "Frederick B. Wilcox"),
        Quote(text: "Don't be afraid to give up the good to go for the great.", author: "John D. Rockefeller"),
        Quote(text: "If you push through that feeling of being scared, that feeling of taking risk, really amazing things can happen.", author: "Marissa Mayer"),
        Quote(text: "Only those who dare to fail greatly can ever achieve greatly.", author: "Robert F. Kennedy"),
        Quote(text: "Risk more than others think is safe. Care more than others think is wise. Dream more than others think is practical. Expect more than others think is possible.", author: "Cadet Maxim"),
        
        // Opening Up and Vulnerability
        Quote(text: "Vulnerability is not weakness; it's our greatest measure of courage.", author: "Brené Brown"),
        Quote(text: "To share your weakness is to make yourself vulnerable; to make yourself vulnerable is to show your strength.", author: "Criss Jami"),
        Quote(text: "What happens when people open their hearts? They get better.", author: "Haruki Murakami"),
        Quote(text: "Vulnerability is the birthplace of love, belonging, joy, courage, empathy, and creativity.", author: "Brené Brown"),
        Quote(text: "Out of your vulnerabilities will come your strength.", author: "Sigmund Freud"),
        Quote(text: "Being vulnerable is the only way to allow your heart to feel true pleasure.", author: "Bob Marley"),
        Quote(text: "Vulnerability is the birthplace of innovation, creativity and change.", author: "Brené Brown"),
        Quote(text: "What makes you vulnerable, makes you beautiful.", author: "Brené Brown"),
        Quote(text: "Owning our story can be hard but not nearly as difficult as spending our lives running from it.", author: "Brené Brown"),
        Quote(text: "Vulnerability sounds like truth and feels like courage. Truth and courage aren't always comfortable, but they're never weakness.", author: "Brené Brown"),
        Quote(text: "Staying vulnerable is a risk we have to take if we want to experience connection.", author: "Brené Brown"),
        Quote(text: "We're never so vulnerable than when we trust someone-but paradoxically, if we cannot trust, neither can we find love or joy.", author: "Walter Inglis Anderson"),
        Quote(text: "Vulnerability is not weakness; it's our most accurate measure of courage.", author: "Brené Brown"),
        Quote(text: "To be alive is to be vulnerable.", author: "Madeleine L'Engle"),
        Quote(text: "Honesty and transparency make you vulnerable. Be honest and transparent anyway.", author: "Mother Teresa"),
        Quote(text: "There can be no vulnerability without risk. There can be no community without vulnerability.", author: "M. Scott Peck"),
        
        // Being Raw and Authentic
        Quote(text: "To be yourself in a world that is constantly trying to make you something else is the greatest accomplishment.", author: "Ralph Waldo Emerson"),
        Quote(text: "Authenticity is the daily practice of letting go of who we think we're supposed to be and embracing who we are.", author: "Brené Brown"),
        Quote(text: "The privilege of a lifetime is to become who you truly are.", author: "Carl Jung"),
        Quote(text: "Be yourself; everyone else is already taken.", author: "Oscar Wilde"),
        Quote(text: "The authentic self is the soul made visible.", author: "Sarah Ban Breathnach"),
        Quote(text: "We have to dare to be ourselves, however frightening or strange that self may prove to be.", author: "May Sarton"),
        Quote(text: "Because true belonging only happens when we present our authentic, imperfect selves to the world, our sense of belonging can never be greater than our level of self-acceptance.", author: "Brené Brown"),
        
        // Being in the Moment
        Quote(text: "Do not dwell in the past, do not dream of the future, concentrate the mind on the present moment.", author: "Buddha"),
        Quote(text: "The ability to be in the present moment is a major component of mental wellness.", author: "Abraham Maslow"),
        Quote(text: "Life is a succession of moments. To live each one is to succeed.", author: "Corita Kent"),
        Quote(text: "Stop acting as if life is a rehearsal. Live this day as if it were your last.", author: "Wayne Dyer"),
        Quote(text: "If you want to conquer the anxiety of life, live in the moment, live in the breath.", author: "Amit Ray"),
        Quote(text: "The present moment is the only time over which we have dominion.", author: "Thích Nhất Hạnh"),
        Quote(text: "The best way to capture moments is to pay attention. This is how we cultivate mindfulness.", author: "Jon Kabat-Zinn"),
        Quote(text: "The future depends on what you do today.", author: "Mahatma Gandhi"),
        
        // Taking a Leap of Faith
        Quote(text: "Leap, and the net will appear.", author: "John Burroughs"),
        Quote(text: "Faith is taking the first step even when you don't see the whole staircase.", author: "Martin Luther King, Jr."),
        Quote(text: "All growth is a leap in the dark, a spontaneous unpremeditated act without benefit of experience.", author: "Henry Miller"),
        Quote(text: "Creativity is always a leap of faith. You're faced with a blank page, blank easel, or an empty stage.", author: "Julia Cameron"),
        
        // Improv & The Spirit of Improvisation
        Quote(text: "Life is an improvisation. You have no idea what's going to happen next and you are mostly just making things up as you go along.", author: "Stephen Colbert"),
        Quote(text: "The rules of improvisation apply beautifully to life. Never say no - you have to be interested to be interesting, and your job is to support your partners.", author: "Scott Adsit"),
        Quote(text: "Life is a lot like jazz... it's best when you improvise.", author: "George Gershwin"),
        Quote(text: "Just say yes and you'll figure it out afterwards.", author: "Tina Fey"),
        Quote(text: "The thing about improvisation is that it's not about what you say. It's listening to what other people say. It's about what you hear.", author: "Paul Merton"),
        Quote(text: "You're only given one little spark of madness. You mustn't lose it.", author: "Robin Williams"),
        Quote(text: "There's power in looking silly and not caring that you do.", author: "Amy Poehler"),
        Quote(text: "Life is improvisation. All of those people who end up being museum pieces are just people who are constantly improvising.", author: "Alan Arkin"),
        
        // The Transformative Power of Journaling
        Quote(text: "Keeping a journal will absolutely change your life in ways you'd never imagine.", author: "Oprah Winfrey"),
        Quote(text: "Journal writing, when it becomes a ritual for transformation, is not only life-changing but life-expanding.", author: "Jennifer Williamson"),
        Quote(text: "Writing is the only way I have to explain my own life to myself.", author: "Pat Conroy"),
        Quote(text: "I write entirely to find out what I'm thinking, what I'm looking at, what I see, and what it means. What I want and what I fear.", author: "Joan Didion"),
        Quote(text: "Keeping a journal of what's going on in your life is a good way to help you distill what's important and what's not.", author: "Martina Navratilova"),
        Quote(text: "I can shake off everything as I write; my sorrows disappear, my courage is reborn.", author: "Anne Frank"),
        Quote(text: "In the journal I do not just express myself more openly than I could to any person; I create myself.", author: "Susan Sontag"),
        Quote(text: "Journaling is like whispering to one's self and listening at the same time.", author: "Mina Murray"),
        Quote(text: "Writing in a journal each day allows you to direct your focus to what you accomplished, what you're grateful for and what you're committed to doing better tomorrow.", author: "Hal Elrod"),
        Quote(text: "The starting point of discovering who you are, your gifts, your talents, your dreams, is being comfortable with yourself. Spend time alone. Write in a journal.", author: "Robin Sharma"),
        Quote(text: "Journal writing gives us insights into who we are, who we were, and who we can become.", author: "Sandra Marinella"),
        
        // The Journey of Self-Discovery
        Quote(text: "Knowing yourself is the beginning of all wisdom.", author: "Aristotle"),
        Quote(text: "To find yourself, think for yourself.", author: "Socrates"),
        Quote(text: "When you know yourself you are empowered. When you accept yourself you are invincible.", author: "Tina Lifford"),
        Quote(text: "Take chances, make mistakes. That's how you grow. Pain nourishes your courage. You have to fail in order to practice being brave.", author: "Mary Tyler Moore"),
        Quote(text: "Our lives improve only when we take chances—and the first and most difficult risk we can take is to be honest with ourselves.", author: "Walter Anderson"),
        Quote(text: "You can't get anywhere in life without taking risks.", author: "Esme Bianco"),
        Quote(text: "Courage doesn't mean you don't get afraid. Courage means you don't let fear stop you.", author: "Bethany Hamilton")
    ].shuffled()
    
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
                    
                    // Dynamic loading animation
                    loadingAnimation
                    
                    // Motivational messaging
                    messagingSection
                        .frame(maxWidth: UIScreen.main.bounds.width - 80)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black) // Fallback background
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            cleanupTimers()
        }
        // Handle server errors gracefully
        .onReceive(NotificationCenter.default.publisher(for: .init("ServerError"))) { notification in
            handleServerError(notification)
        }
    }
    
    private var backgroundGradient: some View {
        ZStack {
            // Static background image - no transitions, no animations
            if !selectedBackgroundImage.isEmpty,
               let uiImage = UIImage(named: selectedBackgroundImage) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
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
            // App logo - static image, no rotation
            ZStack {
                // Glowing effect
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
                    .scaleEffect(vibePulse)
                    .blur(radius: 15)
                
                // Main logo - NO ROTATION
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
                    
                    Image("octopus-transparent-background")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .colorMultiply(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
            }
            .frame(width: 140, height: 140)
            .clipped()
            
            Text(title)
                .font(.system(size: 36, weight: .black, design: .rounded)) // Reduced from 42
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
        .padding(.top, 20) // Extra top padding for safe area
    }
    
    private var loadingAnimation: some View {
        ZStack {
            // Single rotating ring
            Circle()
                .trim(from: 0, to: 0.7)
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
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(ringRotation))
            
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
        .frame(width: 140, height: 140)
        .clipped()
    }
    
    private var messagingSection: some View {
        VStack(spacing: 16) {
            if messageIndex < inspirationalQuotes.count {
                VStack(spacing: 8) {
                    Text(inspirationalQuotes[messageIndex].text)
                        .font(Font.system(size: 16, weight: .medium, design: .rounded).italic())
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(messageOpacity)
                        .animation(.easeInOut(duration: 0.5), value: messageOpacity)
                    
                    Text("— \(inspirationalQuotes[messageIndex].author)")
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
                Text("Something went wrong")
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
                
                Text(errorMessage.isEmpty ? "We encountered an issue while preparing your interview. Let's get you back on track!" : errorMessage)
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
                        Text("Go Back Home")
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
        // Select ONE random background image at startup
        selectedBackgroundImage = backgroundImages.randomElement() ?? backgroundImages[0]
        
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
        
        // Cycle through quotes only - no background changes
        quoteTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { timer in
            guard !hasError else { 
                timer.invalidate()
                return 
            }
            
            withAnimation(.easeOut(duration: 0.5)) {
                messageOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !hasError else { return }
                
                if messageIndex < inspirationalQuotes.count - 1 {
                    messageIndex += 1
                    
                    withAnimation(.easeIn(duration: 0.5)) {
                        messageOpacity = 1
                    }
                } else {
                    // Loop back to beginning
                    messageIndex = 0
                    withAnimation(.easeIn(duration: 0.5)) {
                        messageOpacity = 1
                    }
                }
            }
        }
        
        // Initial message - show immediately
        withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
            messageOpacity = 1
        }
    }
    
    private func cleanupTimers() {
        quoteTimer?.invalidate()
        quoteTimer = nil
    }
    
    private func handleServerError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let statusCode = userInfo["statusCode"] as? Int else { return }
        
        var message = ""
        
        switch statusCode {
        case 500...599:
            message = "Our servers are having a temporary issue. We're working on it!"
        case 404:
            message = "The requested resource was not found. Let's try again."
        case 400...499:
            message = "There was an issue with your request. Please try again."
        default:
            message = "We encountered an unexpected issue. Let's get you back on track!"
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
            logoOpacity = 0
            particlesVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            startAnimations()
        }
    }
}

// Particle effect for extra visual flair
@available(iOS 15.0, macOS 11.0, *)
struct ParticleEffectView: View {
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var size: CGFloat
        var opacity: Double
        var color: Color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .opacity(particle.opacity)
                        .position(particle.position)
                        .blur(radius: particle.size / 10)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles()
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        particles = (0..<30).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -1...1),
                    dy: CGFloat.random(in: -2...(-0.5))
                ),
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.3...0.7),
                color: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent, ColorTheme.tertiaryAccent].randomElement()!
            )
        }
    }
    
    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                for index in particles.indices {
                    particles[index].position.x += particles[index].velocity.dx
                    particles[index].position.y += particles[index].velocity.dy
                    
                    // Reset particle if it goes off screen
                    if particles[index].position.y < -10 {
                        let screenHeight = max(800, UIScreen.main.bounds.height)
                        let screenWidth = max(400, UIScreen.main.bounds.width)
                        particles[index].position.y = screenHeight + 10
                        particles[index].position.x = CGFloat.random(in: 0...screenWidth)
                    }
                }
            }
        }
    }
}

#Preview {
    InterviewCreationLoadingView()
}