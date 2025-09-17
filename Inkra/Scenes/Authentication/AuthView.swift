import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
public struct AuthView: View {
    @StateObject private var authService = AuthService.shared
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    // Interests onboarding disabled - using custom topics only
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Logo/Title
                VStack(spacing: 8) {
                    Text("VibeWrite")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Transform your stories into structured transcripts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Auth Form
                VStack(spacing: 16) {
                    // Mode Picker
                    Picker("Auth Mode", selection: $isLoginMode) {
                        Text("Sign In").tag(true)
                        Text("Sign Up").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 8)
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(isLoading)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(isLoginMode ? .password : .newPassword)
                            .disabled(isLoading)
                    }
                    
                    // Password Confirmation (only for registration)
                    if !isLoginMode {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Confirm Password")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("Confirm your password", text: $passwordConfirmation)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.newPassword)
                                .disabled(isLoading)
                        }
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Auth Button
                    Button(action: performAuth) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoginMode ? "Sign In" : "Sign Up")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || !isFormValid)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .onChange(of: isLoginMode) { _ in
            errorMessage = nil
            passwordConfirmation = ""
        }
        // Interests onboarding sheet removed
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && 
        !password.isEmpty && 
        (isLoginMode || (!passwordConfirmation.isEmpty && password == passwordConfirmation))
    }
    
    private func performAuth() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                if isLoginMode {
                    try await authService.login(email: email, password: password)
                } else {
                    try await authService.register(
                        email: email,
                        password: password,
                        passwordConfirmation: passwordConfirmation
                    )
                    // Skip interests onboarding - using custom topics only
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthView()
}