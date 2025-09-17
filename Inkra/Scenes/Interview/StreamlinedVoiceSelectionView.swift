import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct StreamlinedVoiceSelectionView: View {
    @State private var selectedVoiceId = "Matthew"
    @State private var speechRate = 1.0
    @State private var showVoiceSelection = false
    @State private var navigateToVoiceTopicInput = false
    @State private var navigateToReadingTopicInput = false
    @StateObject private var voiceService = VoiceService.shared
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Let's Start Your Interview")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Choose your interview style")
                    .font(.body)
                    .foregroundColor(ColorTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                // Voice Interview Section (Default)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Spoken Interview")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTheme.primaryText)
                    
                    Button(action: {
                        showVoiceSelection = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Voice: \(selectedVoiceId)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(ColorTheme.primaryText)
                                
                                Text(String(format: "Speed: %.1fx", speechRate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ColorTheme.primaryAccent.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                
                // Continue with Voice Button (Primary)
                Button(action: {
                    navigateToVoiceTopicInput = true
                }) {
                    HStack {
                        Image(systemName: "waveform.and.mic")
                        Text("Continue with Spoken Interview")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ColorTheme.primaryAccent)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                
                // Alternative: Reading Interview (Secondary)
                Button(action: {
                    navigateToReadingTopicInput = true
                }) {
                    HStack {
                        Image(systemName: "text.book.closed")
                        Text("Switch to Reading Interview")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(ColorTheme.primaryAccent)
                    .font(.subheadline)
                }
                .padding(.top, 8)
            }
            
            Spacer()
            Spacer()
        }
        .navigationTitle("New Interview")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.primaryBackground)
        .sheet(isPresented: $showVoiceSelection) {
            VoiceSelectionView(initialVoiceId: selectedVoiceId, initialSpeechRate: speechRate) { voiceId, rate in
                selectedVoiceId = voiceId
                speechRate = rate
            }
        }
        .background(
            NavigationLink(
                destination: StreamlinedVoiceTopicView(selectedVoiceId: selectedVoiceId, speechRate: speechRate),
                isActive: $navigateToVoiceTopicInput
            ) {
                EmptyView()
            }
        )
        .background(
            NavigationLink(
                destination: ReadingInterviewTopicView(interviewLength: .tenMinutes),
                isActive: $navigateToReadingTopicInput
            ) {
                EmptyView()
            }
        )
        .task {
            // Fetch voices when view appears
            await voiceService.fetchAndCacheVoices()
        }
    }
}

#Preview {
    StreamlinedVoiceSelectionView()
}