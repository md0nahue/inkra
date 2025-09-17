import SwiftUI

enum InterviewLength: CaseIterable {
    case fiveMinutes
    case tenMinutes
    case twentyMinutes
    case unlimited
    
    var displayName: String {
        switch self {
        case .fiveMinutes:
            return "5 minutes"
        case .tenMinutes:
            return "10 minutes"
        case .twentyMinutes:
            return "20 minutes"
        case .unlimited:
            return "Unlimited"
        }
    }
    
    var description: String {
        switch self {
        case .fiveMinutes:
            return "5 questions + follow-ups"
        case .tenMinutes:
            return "10 questions + follow-ups"
        case .twentyMinutes:
            return "20 questions + follow-ups"
        case .unlimited:
            return "Continuous interview with dynamic questions"
        }
    }
    
    var iconName: String {
        switch self {
        case .fiveMinutes:
            return "timer"
        case .tenMinutes:
            return "timer.circle"
        case .twentyMinutes:
            return "timer.circle.fill"
        case .unlimited:
            return "infinity.circle.fill"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .fiveMinutes:
            return .green
        case .tenMinutes:
            return .blue
        case .twentyMinutes:
            return .orange
        case .unlimited:
            return .purple
        }
    }
    
    var questionCount: Int {
        switch self {
        case .fiveMinutes:
            return 5
        case .tenMinutes:
            return 10
        case .twentyMinutes:
            return 20
        case .unlimited:
            return 40 // Initial batch for unlimited
        }
    }
    
    var isDefault: Bool {
        self == .tenMinutes
    }
    
    var apiValue: String {
        switch self {
        case .fiveMinutes:
            return "5_minutes"
        case .tenMinutes:
            return "10_minutes"
        case .twentyMinutes:
            return "20_minutes"
        case .unlimited:
            return "unlimited"
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct InterviewLengthSelectionView: View {
    let interviewType: InterviewTypeSelectionView.InterviewType
    @State private var selectedLength: InterviewLength = .tenMinutes
    @State private var navigateToNext = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Choose Interview Length")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("How much time would you like to spend?")
                    .font(.body)
                    .foregroundColor(ColorTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                ForEach(InterviewLength.allCases, id: \.self) { length in
                    Button(action: {
                        selectedLength = length
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: length.iconName)
                                .font(.system(size: 28))
                                .foregroundColor(length.accentColor)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(length.displayName)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(ColorTheme.primaryText)
                                    
                                    if length.isDefault {
                                        Text("DEFAULT")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(ColorTheme.primaryAccent)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text(length.description)
                                    .font(.caption)
                                    .foregroundColor(ColorTheme.secondaryText)
                            }
                            
                            Spacer()
                            
                            Image(systemName: selectedLength == length ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(selectedLength == length ? length.accentColor : ColorTheme.tertiaryText)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ColorTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedLength == length ? length.accentColor.opacity(0.5) : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            
            Button(action: {
                navigateToNext = true
            }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [ColorTheme.primaryAccent, ColorTheme.secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .navigationTitle("Interview Length")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            NavigationLink(
                destination: destinationView,
                isActive: $navigateToNext
            ) {
                EmptyView()
            }
        )
        .background(ColorTheme.primaryBackground)
    }
    
    @ViewBuilder
    private var destinationView: some View {
        switch interviewType {
        case .reading:
            ReadingInterviewTopicView(interviewLength: selectedLength)
        case .speaking:
            VoiceSelectionFirstView(interviewLength: selectedLength)
        }
    }
}

#Preview {
    NavigationView {
        InterviewLengthSelectionView(interviewType: .speaking)
    }
}