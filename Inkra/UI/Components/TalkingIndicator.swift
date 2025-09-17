import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct TalkingIndicator: View {
    enum State {
        case idle
        case listening
        case speaking
        case aiSpeaking
    }
    
    let state: State
    let size: CGFloat
    
    init(state: State, size: CGFloat = 140) {
        self.state = state
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .strokeBorder(stateColor.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
            
            // Inner fill
            Circle()
                .fill(stateColor.opacity(0.1))
                .frame(width: size * 0.85, height: size * 0.85)
            
            // Icon
            Image(systemName: stateIcon)
                .font(.system(size: size * 0.28, weight: .medium))
                .foregroundColor(stateColor)
        }
    }
    
    private var stateColor: Color {
        switch state {
        case .idle:
            return Color.white.opacity(0.6)
        case .listening:
            return ColorTheme.primaryAccent
        case .speaking:
            return .green
        case .aiSpeaking:
            return ColorTheme.secondaryAccent
        }
    }
    
    private var stateIcon: String {
        switch state {
        case .idle:
            return "mic"
        case .listening:
            return "mic.fill"
        case .speaking:
            return "waveform"
        case .aiSpeaking:
            return "speaker.wave.2.fill"
        }
    }
}

// MARK: - Status Text Component

@available(iOS 15.0, macOS 11.0, *)
struct TalkingStatusText: View {
    enum Status {
        case idle
        case listening
        case speechDetected
        case aiSpeaking
    }
    
    let status: Status
    
    var body: some View {
        Text(statusText)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(statusColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(statusColor.opacity(0.2))
            .cornerRadius(16)
            .frame(height: 32) // Fixed height to prevent layout jumps
    }
    
    private var statusText: String {
        switch status {
        case .idle:
            return "Ready to Record"
        case .listening:
            return "Listening..."
        case .speechDetected:
            return "Speech Detected"
        case .aiSpeaking:
            return "AI Speaking"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .idle:
            return .white.opacity(0.6)
        case .listening:
            return ColorTheme.primaryAccent
        case .speechDetected:
            return .green
        case .aiSpeaking:
            return ColorTheme.secondaryAccent
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        Group {
            TalkingIndicator(state: .idle)
            TalkingIndicator(state: .listening)
            TalkingIndicator(state: .speaking)
            TalkingIndicator(state: .aiSpeaking)
        }
        
        Divider()
        
        VStack(spacing: 16) {
            TalkingStatusText(status: .idle)
            TalkingStatusText(status: .listening)
            TalkingStatusText(status: .speechDetected)
            TalkingStatusText(status: .aiSpeaking)
        }
    }
    .padding()
    .background(Color.black)
}