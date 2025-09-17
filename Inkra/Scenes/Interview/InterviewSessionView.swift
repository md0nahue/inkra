import SwiftUI
import AVFoundation

@available(iOS 15.0, macOS 11.0, *)
struct InterviewSessionView: View {
    @StateObject private var engine: InterviewEngine
    @State private var showingSummary = false
    @State private var navigateToSummary = false
    @State private var breathingAnimation = false
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    
    init(project: Project) {
        self.project = project
        self._engine = StateObject(wrappedValue: InterviewEngine(project: project))
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.16),
                    Color(red: 0.12, green: 0.08, blue: 0.20),
                    Color(red: 0.16, green: 0.12, blue: 0.24)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                headerView
                
                // Main content based on state
                mainContent
                
                // Controls
                if engine.state != .completed && engine.state != .error {
                    controlsView
                }
            }
            .padding()
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await engine.startInterview()
            }
            breathingAnimation = true
        }
        .onDisappear {
            Task {
                await engine.endInterview()
            }
        }
        .background(
            NavigationLink(
                destination: ProjectDetailView(project: project),
                isActive: $navigateToSummary
            ) {
                EmptyView()
            }
        )
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button(action: { 
                Task {
                    await engine.endInterview()
                }
                // Navigation will be handled by PostInterviewLoadingView
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            if engine.totalQuestions > 0 {
                Text("Question \(engine.currentQuestionIndex + 1) of \(engine.totalQuestions)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Placeholder for symmetry
            Circle()
                .fill(Color.clear)
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 30) {
            switch engine.state {
            case .idle, .initializing:
                loadingView
                
            case .loadingQuestion:
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading next question...")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
            case .playingQuestion:
                if project.isSpeechInterview == true {
                    speechQuestionPlayingView
                } else {
                    readingQuestionView
                }
                
            case .listening:
                if project.isSpeechInterview == true {
                    listeningView
                } else {
                    readingQuestionView
                }
                
                
            case .paused:
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(.yellow.opacity(0.2))
                            .frame(width: 90, height: 90)
                        
                        Image(systemName: "map.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .scaleEffect(breathingAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: breathingAnimation)
                    
                    VStack(spacing: 8) {
                        Text("Taking a breath...")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text("Your journey continues when you're ready")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                
            case .completed:
                PostInterviewLoadingView(
                    title: "Processing Your Interview",
                    message: "Your responses are being finalized...",
                    onDismiss: { navigateToSummary = true }
                )
                
            case .error:
                errorView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        InterviewCreationLoadingView(
            title: "Finalizing Your Interview",
            message: project.isSpeechInterview == true ? "Setting up your voice experience..." : "Organizing your questions..."
        )
    }
    
    @ViewBuilder
    private var speechQuestionPlayingView: some View {
        VStack(spacing: 25) {
            if let question = engine.currentQuestion {
                // Follow-up question indicator
                if question.isFollowUp {
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption)
                        Text("Follow-up Question")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Question text
                ScrollView {
                    Text(question.text)
                        .font(.title2)
                        .minimumScaleFactor(0.5)  // Allow text to shrink to 50% if needed
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .frame(maxHeight: 300)
                
                // Clean audio playing indicator
                VStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                    Text("Playing question...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
    
    @ViewBuilder
    private var readingQuestionView: some View {
        VStack(spacing: 25) {
            if let question = engine.currentQuestion {
                // Section and chapter info
                VStack(spacing: 8) {
                    Text(question.chapterTitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Text(question.sectionTitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Follow-up question indicator
                if question.isFollowUp {
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption)
                        Text("Follow-up Question")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Question text
                ScrollView {
                    Text(question.text)
                        .font(.title2)
                        .minimumScaleFactor(0.5)  // Allow text to shrink to 50% if needed
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .frame(maxHeight: 400)
                
                // Reading indicator
                Text("Take your time to read and reflect")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    @ViewBuilder
    private var listeningView: some View {
        VStack(spacing: 25) {
            if let question = engine.currentQuestion {
                // Follow-up question indicator
                if question.isFollowUp {
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption)
                        Text("Follow-up Question")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Question text - keep larger format with rounded box
                ScrollView {
                    Text(question.text)
                        .font(.title2)
                        .minimumScaleFactor(0.5)  // Allow text to shrink to 50% if needed
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .frame(maxHeight: 300)
            }
            
            // Clean recording indicator with user speaking feedback
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        )
                    
                    VStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red.opacity(0.8))
                        
                        if engine.silenceCountdown > 0 {
                            Text("\(engine.silenceCountdown)")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.red.opacity(0.8))
                        } else {
                            Text("Listening...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                // User speaking indicator - only show when actually listening/recording
                if engine.audioLevel > 0.1 && engine.isRecording && (engine.state == .listening) {  // Enhanced validation
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        Text("You are talking!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.green.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: engine.audioLevel)
                    .onAppear {
                        print("[InterviewSessionView] ✅ 'You are talking!' indicator appeared - audioLevel: \(engine.audioLevel), state: \(engine.state), isRecording: \(engine.isRecording)")
                    }
                    .onDisappear {
                        print("[InterviewSessionView] ❌ 'You are talking!' indicator disappeared - audioLevel: \(engine.audioLevel), state: \(engine.state), isRecording: \(engine.isRecording)")
                    }
                }
            }
            
        }
    }
    
    
    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if let errorMessage = engine.errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
            
            Button(action: {
                Task {
                    await engine.startInterview()
                }
            }) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
    
    @ViewBuilder
    private var controlsView: some View {
        VStack(spacing: 20) {
            if project.isSpeechInterview == true {
                speechInterviewControls
            } else {
                readingInterviewControls
            }
            
            // Auto-advance toggle (speech interviews only)
            if project.isSpeechInterview == true {
                Toggle(isOn: $engine.autoAdvanceEnabled) {
                    Label("Auto-advance on silence", systemImage: "forward.end.alt.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.horizontal, 40)
            }
            
            // End Interview button (for all interview types)
            Button(action: {
                Task {
                    await engine.stopAudioPlayback()
                    await engine.endInterview()
                }
                // Navigation will be handled by PostInterviewLoadingView
            }) {
                HStack(spacing: 8) {
                    Text("End Interview")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "stop.circle")
                        .font(.subheadline)
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.red.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    @ViewBuilder
    private var speechInterviewControls: some View {
        HStack(spacing: 30) {
            // Skip button
            Button(action: {
                Task {
                    await engine.stopAudioPlayback()
                    await engine.skipQuestion()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.6))
                    Text("Skip")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .disabled(engine.state != .listening && engine.state != .playingQuestion)
            .opacity(engine.state == .listening || engine.state == .playingQuestion ? 1.0 : 0.5)
            
            // Pause/Resume button
            if engine.state == .paused {
                Button(action: {
                    Task {
                        await engine.resumeInterview()
                    }
                }) {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            } else if engine.state == .listening || engine.state == .playingQuestion {
                Button(action: {
                    Task {
                        await engine.pauseInterview()
                    }
                }) {
                    Image(systemName: "pause.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
            
            // Next button
            Button(action: {
                Task {
                    await engine.stopAudioPlayback()
                    await engine.nextQuestion()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                    Text("Next")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .disabled(engine.state != .listening)
            .opacity(engine.state == .listening ? 1.0 : 0.5)
        }
    }
    
    @ViewBuilder
    private var readingInterviewControls: some View {
        HStack(spacing: 30) {
            // Previous button (if not first question)
            if engine.currentQuestionIndex > 0 {
                Button(action: {
                    // TODO: Implement previous question
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
            
            // Next button
            Button(action: {
                Task {
                    await engine.stopAudioPlayback()
                    await engine.nextQuestion()
                }
            }) {
                HStack(spacing: 8) {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.medium)
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
}