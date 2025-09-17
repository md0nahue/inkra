import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct VoiceSelectionFirstView: View {
    let interviewLength: InterviewLength
    @State private var selectedVoiceId = "Matthew"
    @State private var speechRate = 1.0
    @State private var showVoiceSelection = false
    @State private var navigateToTopicInput = false
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
                
                Text("Choose Your AI Voice")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Select the voice that will guide your interview")
                    .font(.body)
                    .foregroundColor(ColorTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                // Voice Configuration Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Voice Settings")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Button(action: {
                        showVoiceSelection = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Voice: \(selectedVoiceId)")
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
                
                // Continue Button
                Button(action: {
                    navigateToTopicInput = true
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ColorTheme.primaryAccent)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
            Spacer()
        }
        .navigationTitle("Voice Interview")
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
                destination: VoiceInterviewTopicView(selectedVoiceId: selectedVoiceId, speechRate: speechRate, interviewLength: interviewLength),
                isActive: $navigateToTopicInput
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
    VoiceSelectionFirstView(interviewLength: .tenMinutes)
}