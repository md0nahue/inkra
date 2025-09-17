import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var feedbackService = FeedbackService.shared
    
    @State private var feedbackText: String = ""
    @State private var selectedFeedbackType: FeedbackType = .general
    @State private var email: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showingSuccess: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    private let characterLimit = 2000
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    feedbackTypeSection
                    feedbackTextSection
                    emailSection
                    submitSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(ColorTheme.primaryBackground)
            .navigationTitle("Leave Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ColorTheme.primaryAccent)
                }
            }
            .alert("Feedback Sent!", isPresented: $showingSuccess) {
                Button("Great!") {
                    dismiss()
                }
            } message: {
                Text("Thank you for helping us improve Inkra! We truly appreciate your input.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundColor(ColorTheme.tertiaryAccent)
                    .font(.title2)
                
                Text("We Value Your Input")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTheme.primaryText)
            }
            
            Text("We value each user of Inkra and want to make this as useful as possible for our users. Please share any feedback you might have about feature requests, how you use it, or how it could be improved.")
                .font(.body)
                .foregroundColor(ColorTheme.secondaryText)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .darkModeCard()
    }
    
    private var feedbackTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(ColorTheme.primaryAccent)
                    .font(.headline)
                
                Text("Feedback Type")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTheme.primaryText)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(FeedbackType.allCases) { type in
                    Button(action: {
                        selectedFeedbackType = type
                        HapticManager.shared.impact(.light)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(type.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(selectedFeedbackType == type ? .white : ColorTheme.primaryText)
                        .background(
                            selectedFeedbackType == type 
                                ? ColorTheme.primaryAccent 
                                : ColorTheme.tertiaryBackground
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedFeedbackType == type 
                                        ? ColorTheme.primaryAccent 
                                        : ColorTheme.cardBorder, 
                                    lineWidth: selectedFeedbackType == type ? 0 : 0.5
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .darkModeCard()
    }
    
    private var feedbackTextSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(ColorTheme.primaryAccent)
                    .font(.headline)
                
                Text("Your Feedback")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTheme.primaryText)
                
                Spacer()
                
                Text("\(feedbackText.count)/\(characterLimit)")
                    .font(.caption)
                    .foregroundColor(
                        feedbackText.count > characterLimit * 9 / 10 
                            ? ColorTheme.warning 
                            : ColorTheme.tertiaryText
                    )
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $feedbackText)
                    .font(.body)
                    .foregroundColor(ColorTheme.primaryText)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(ColorTheme.tertiaryBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorTheme.cardBorder, lineWidth: 0.5)
                    )
                    .onChange(of: feedbackText) { newValue in
                        if newValue.count > characterLimit {
                            feedbackText = String(newValue.prefix(characterLimit))
                        }
                    }
                
                if feedbackText.isEmpty {
                    Text("Please share your thoughts, suggestions, or report any issues you've encountered...")
                        .font(.body)
                        .foregroundColor(ColorTheme.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(20)
        .darkModeCard()
    }
    
    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(ColorTheme.primaryAccent)
                    .font(.headline)
                
                Text("Email (Optional)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTheme.primaryText)
            }
            
            TextField("", text: $email)
                .font(.body)
                .foregroundColor(ColorTheme.primaryText)
                .padding(12)
                .background(ColorTheme.tertiaryBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTheme.cardBorder, lineWidth: 0.5)
                )
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
            
            Text("If you'd like us to follow up with you about this feedback.")
                .font(.caption)
                .foregroundColor(ColorTheme.tertiaryText)
        }
        .padding(20)
        .darkModeCard()
    }
    
    private var submitSection: some View {
        VStack(spacing: 16) {
            Button(action: submitFeedback) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(isSubmitting ? "Sending..." : "Send Feedback")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(
                    isFormValid 
                        ? ColorTheme.primaryAccent 
                        : ColorTheme.tertiaryText.opacity(0.3)
                )
                .cornerRadius(12)
                .shadow(
                    color: isFormValid 
                        ? ColorTheme.primaryAccent.opacity(0.3) 
                        : Color.clear, 
                    radius: 8, x: 0, y: 4
                )
            }
            .disabled(!isFormValid || isSubmitting)
            .buttonStyle(PlainButtonStyle())
            
            Text("Your feedback helps us make Inkra better for everyone.")
                .font(.caption)
                .foregroundColor(ColorTheme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }
    
    private var isFormValid: Bool {
        !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        feedbackText.count >= 10 && 
        feedbackText.count <= characterLimit &&
        (email.isEmpty || isValidEmail(email))
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailTest.evaluate(with: email)
    }
    
    private func submitFeedback() {
        guard isFormValid else { return }
        
        isSubmitting = true
        HapticManager.shared.impact(.medium)
        
        Task {
            do {
                _ = try await feedbackService.submitFeedback(
                    text: feedbackText.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: selectedFeedbackType,
                    email: email.isEmpty ? nil : email
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showingSuccess = true
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// Haptic feedback helper
struct HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}

#Preview {
    if #available(iOS 17.0, macOS 11.0, *) {
        FeedbackView()
    } else {
        Text("iOS 17+ Required")
    }
}