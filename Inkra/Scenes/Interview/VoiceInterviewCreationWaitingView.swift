import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct VoiceInterviewCreationWaitingView: View {
    @State private var currentImageIndex = 0
    @State private var imageOpacity = 1.0
    @State private var showProgressIndicator = true
    @State private var imageTimer: Timer?
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var isStable = true
    
    // Callback for error handling
    var onError: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    // List of atmospheric images to cycle through
    let backgroundImages = [
        "atmospheric-background-1",
        "atmospheric-background-2", 
        "atmospheric-background-3",
        "dawn-walker-eye-level-atmospheric",
        "mountain-sage-triumphant-landscape",
        "window-gazer-atmospheric-mood",
        "forest-silhouette",
        "lakeside-silhouette",
        "city-woman"
    ]
    
    var body: some View {
        ZStack {
            // Full-screen stable background
            Color.black
                .ignoresSafeArea()
            
            // Background image - stable version
            if isStable && !hasError {
                backgroundImageView
                    .ignoresSafeArea()
            } else {
                // Fallback gradient - always stable
                LinearGradient(
                    colors: [
                        ColorTheme.primaryBackground,
                        ColorTheme.secondaryBackground.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            // Dark overlay for better text readability
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Content overlay
            VStack {
                if hasError {
                    errorView
                } else {
                    Spacer()
                    
                    // Stable loading indicator at bottom
                    if showProgressIndicator {
                        VStack(spacing: 20) {
                            // Minimal progress indicator
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Preparing your interview...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .onAppear {
            startStableImageDisplay()
        }
        .onDisappear {
            cleanupTimers()
        }
        // Handle server errors gracefully
        .onReceive(NotificationCenter.default.publisher(for: .init("ServerError"))) { notification in
            handleServerError(notification)
        }
    }
    
    // Create a stable background view
    private var backgroundImageView: some View {
        Group {
            if currentImageIndex < backgroundImages.count {
                Image(backgroundImages[currentImageIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(imageOpacity)
                    .transition(.opacity)
            } else {
                // Fallback to first image if index is out of bounds
                Image(backgroundImages[0])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(imageOpacity)
                    .transition(.opacity)
            }
        }
    }
    
    // Error view for graceful error handling
    private var errorView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Friendly error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .background(
                    Circle()
                        .fill(.orange.opacity(0.1))
                        .frame(width: 120, height: 120)
                )
            
            VStack(spacing: 12) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(errorMessage.isEmpty ? "We encountered an issue while preparing your interview. Let's get you back on track!" : errorMessage)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    // Try again - restart the loading process
                    resetToLoadingState()
                }) {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    onDismiss?()
                }) {
                    Text("Go Back Home")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }
    
    private func startStableImageDisplay() {
        // Only start image carousel if we're in a stable state
        guard isStable && !hasError else { return }
        
        // Set initial state
        currentImageIndex = Int.random(in: 0..<backgroundImages.count)
        imageOpacity = 1.0
        
        // Change image every 8 seconds (longer interval for stability)
        imageTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            // Only proceed if we're still stable
            guard isStable && !hasError else { return }
            
            withAnimation(.easeInOut(duration: 1.5)) {
                currentImageIndex = (currentImageIndex + 1) % backgroundImages.count
            }
        }
    }
    
    private func cleanupTimers() {
        imageTimer?.invalidate()
        imageTimer = nil
    }
    
    private func handleServerError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let statusCode = userInfo["statusCode"] as? Int else { return }
        
        // Handle 500 errors and other server issues
        if statusCode >= 500 {
            showError(message: "Our servers are having a temporary issue. Please try again in a moment.")
        } else if statusCode == 404 {
            showError(message: "The requested resource was not found. Please try again.")
        } else {
            showError(message: "We encountered an unexpected issue. Please try again.")
        }
    }
    
    private func showError(message: String) {
        cleanupTimers()
        
        withAnimation(.easeInOut(duration: 0.5)) {
            hasError = true
            errorMessage = message
            isStable = false
        }
        
        onError?()
    }
    
    private func resetToLoadingState() {
        withAnimation(.easeInOut(duration: 0.5)) {
            hasError = false
            errorMessage = ""
            isStable = true
            imageOpacity = 1.0
        }
        
        // Restart image display
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startStableImageDisplay()
        }
    }
}


#Preview {
    VoiceInterviewCreationWaitingView()
}