import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct InterviewTypeSelectionView: View {
    @State private var navigateToVoiceSelection = false
    @State private var navigateToReadingTopicInput = false
    @State private var selectedInterviewType: InterviewType?
    
    enum InterviewType {
        case reading
        case speaking
    }
    
    var body: some View {
        VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Choose Your Interview Style")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(ColorTheme.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("How would you like to experience your interview?")
                        .font(.body)
                        .foregroundColor(ColorTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 20) {
                    // Reading Mode Option
                    Button(action: {
                        selectedInterviewType = .reading
                        navigateToReadingTopicInput = true
                    }) {
                        HStack(spacing: 20) {
                            Image(systemName: "text.book.closed.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.blue)
                                .frame(width: 60)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Reading Mode")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(ColorTheme.primaryText)
                                
                                Text("Read questions and respond at your own pace")
                                    .font(.subheadline)
                                    .foregroundColor(ColorTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18))
                                .foregroundColor(ColorTheme.tertiaryText)
                        }
                        .padding(20)
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(ColorTheme.primaryAccent.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Speaking Mode Option
                    Button(action: {
                        selectedInterviewType = .speaking
                        navigateToVoiceSelection = true
                    }) {
                        HStack(spacing: 20) {
                            Image(systemName: "waveform.and.mic")
                                .font(.system(size: 36))
                                .foregroundColor(.purple)
                                .frame(width: 60)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Spoken Interview")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(ColorTheme.primaryText)
                                
                                Text("AI reads questions aloud and advances automatically")
                                    .font(.subheadline)
                                    .foregroundColor(ColorTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18))
                                .foregroundColor(ColorTheme.tertiaryText)
                        }
                        .padding(20)
                        .background(ColorTheme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(ColorTheme.primaryAccent.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                
                Spacer()
                Spacer()
        }
        .navigationTitle("New Interview")
            .navigationBarTitleDisplayMode(.inline)
            .background(
                NavigationLink(
                    destination: InterviewLengthSelectionView(interviewType: selectedInterviewType ?? .speaking),
                    isActive: $navigateToVoiceSelection
                ) {
                    EmptyView()
                }
            )
            .background(
                NavigationLink(
                    destination: InterviewLengthSelectionView(interviewType: selectedInterviewType ?? .reading),
                    isActive: $navigateToReadingTopicInput
                ) {
                    EmptyView()
                }
            )
            .background(ColorTheme.primaryBackground)
    }
}

#Preview {
    InterviewTypeSelectionView()
}