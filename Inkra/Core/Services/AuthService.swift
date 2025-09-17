import Foundation
import KeychainAccess

@available(iOS 15.0, macOS 11.0, *)
@MainActor
public class AuthService: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    
    private let keychain = Keychain(service: "com.vibewrite.app")
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    private let userKey = "current_user"
    private var isManualLogout = false
    
    public static let shared = AuthService()
    
    private init() {
        loadStoredAuth()
    }
    
    var accessToken: String? {
        return keychain[accessTokenKey]
    }
    
    var refreshToken: String? {
        return keychain[refreshTokenKey]
    }
    
    var currentUserEmail: String? {
        return currentUser?.email
    }
    
    func login(email: String, password: String) async throws {
        print("🔐 [AUTH] Starting login for email: \(email)")
        
        let request = LoginRequest(email: email, password: password)
        print("🔐 [AUTH] Login request created, making network call...")
        
        do {
            let response: AuthResponse = try await NetworkService.shared.post("/api/auth/login", body: request)
            print("🔐 [AUTH] Login response received successfully")
            print("🔐 [AUTH] User ID: \(response.user.id), Email: \(response.user.email)")
            print("🔐 [AUTH] CreatedAt: \(response.user.createdAt)")
            print("🔐 [AUTH] AccessToken present: \(response.accessToken.count > 0)")
            print("🔐 [AUTH] RefreshToken present: \(response.refreshToken.count > 0)")
            
            print("🔐 [AUTH] Storing tokens to keychain...")
            try storeTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
            print("🔐 [AUTH] Tokens stored successfully")
            
            print("🔐 [AUTH] Setting current user...")
            await setCurrentUser(response.user)
            print("🔐 [AUTH] Login completed successfully")
            
        } catch {
            print("❌ [AUTH] Login failed with error: \(error)")
            if let authError = error as? AuthError {
                print("❌ [AUTH] AuthError details: \(authError.errorDescription ?? "unknown")")
            }
            throw error
        }
    }
    
    func register(email: String, password: String, passwordConfirmation: String) async throws {
        print("🔐 [AUTH] Starting registration for email: \(email)")
        
        let request = RegisterRequest(
            user: RegisterUserData(
                email: email,
                password: password,
                passwordConfirmation: passwordConfirmation
            )
        )
        print("🔐 [AUTH] Registration request created, making network call...")
        
        do {
            let response: AuthResponse = try await NetworkService.shared.post("/api/auth/register", body: request)
            print("🔐 [AUTH] Registration response received successfully")
            print("🔐 [AUTH] User ID: \(response.user.id), Email: \(response.user.email)")
            print("🔐 [AUTH] CreatedAt: \(response.user.createdAt)")
            print("🔐 [AUTH] AccessToken present: \(response.accessToken.count > 0)")
            print("🔐 [AUTH] RefreshToken present: \(response.refreshToken.count > 0)")
            
            print("🔐 [AUTH] Storing tokens to keychain...")
            try storeTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
            print("🔐 [AUTH] Tokens stored successfully")
            
            print("🔐 [AUTH] Setting current user...")
            await setCurrentUser(response.user)
            print("🔐 [AUTH] Registration completed successfully")
            
        } catch {
            print("❌ [AUTH] Registration failed with error: \(error)")
            if let authError = error as? AuthError {
                print("❌ [AUTH] AuthError details: \(authError.errorDescription ?? "unknown")")
            }
            throw error
        }
    }
    
    func refreshAccessToken() async throws {
        print("🔐 [AUTH] Starting token refresh...")
        
        guard let refreshToken = refreshToken else {
            print("❌ [AUTH] No refresh token available for refresh")
            throw AuthError.noRefreshToken
        }
        
        print("🔐 [AUTH] RefreshToken available, making refresh request...")
        
        do {
            let request = RefreshRequest(refreshToken: refreshToken)
            let response: RefreshResponse = try await NetworkService.shared.post("/api/auth/refresh", body: request)
            
            print("🔐 [AUTH] Refresh response received")
            print("🔐 [AUTH] New AccessToken present: \(response.accessToken.count > 0)")
            print("🔐 [AUTH] New RefreshToken present: \(response.refreshToken.count > 0)")
            
            try storeTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
            print("🔐 [AUTH] Token refresh completed successfully")
            
        } catch {
            print("❌ [AUTH] Token refresh failed: \(error)")
            throw error
        }
    }
    
    func logout() async throws {
        print("🔐 [AUTH] Starting logout process...")
        
        // Set flag to indicate this is a manual logout
        isManualLogout = true
        
        // Call logout endpoint if we have tokens
        if accessToken != nil {
            print("🔐 [AUTH] Access token available, calling server logout...")
            do {
                let _: LogoutResponse = try await NetworkService.shared.post("/api/auth/logout", body: EmptyBody())
                print("🔐 [AUTH] Server logout successful")
            } catch NetworkError.unauthorized {
                // Token already expired - this is expected during manual logout
                print("🔐 [AUTH] Token already expired during logout - continuing with local logout...")
            } catch {
                // Continue with local logout even if server call fails
                print("⚠️ [AUTH] Server logout failed: \\(error)")
                print("🔐 [AUTH] Continuing with local logout...")
            }
        } else {
            print("🔐 [AUTH] No access token, skipping server logout")
        }
        
        print("🔐 [AUTH] Clearing stored auth data...")
        clearStoredAuth()
        isManualLogout = false
        print("🔐 [AUTH] Logout completed")
    }
    
    func deleteAccount(reason: String) async throws {
        // Use the new UserLifecycleService for comprehensive account deletion
        let lifecycleService = UserLifecycleService.shared
        let _ = try await lifecycleService.deleteAccount(
            experienceDescription: reason,
            whatWouldChange: nil,
            requestExport: false
        )
        
        clearStoredAuth()
    }
    
    func updateUserInterests(_ interests: [String]) {
        guard let user = currentUser else { return }
        
        let updatedUser = User(
            id: user.id,
            email: user.email,
            createdAt: user.createdAt,
            interests: interests
        )
        
        currentUser = updatedUser
        
        // Store updated user data
        do {
            let userData = try JSONEncoder().encode(updatedUser)
            keychain[data: userKey] = userData
            print("🔐 [AUTH] Updated user interests and stored to keychain")
        } catch {
            print("❌ [AUTH] Failed to encode/store updated user data: \(error)")
        }
    }
    
    func handleUnauthorizedAccess() async {
        print("❌ [AUTH] Unauthorized access detected - logging out user")
        print("🔐 [AUTH] Current login status before clearing: \(isLoggedIn)")
        print("🔐 [AUTH] Current user before clearing: \(currentUser?.email ?? "nil")")
        print("🔐 [AUTH] Is manual logout: \(isManualLogout)")
        
        clearStoredAuth()
        
        // Only show session expired message if this is not a manual logout
        if !isManualLogout {
            print("🔐 [AUTH] Auth data cleared, showing session expired message...")
            AppStateService.shared.showSessionExpiredMessage()
        } else {
            print("🔐 [AUTH] Manual logout in progress, skipping session expired message")
        }
    }
    
    private func storeTokens(accessToken: String, refreshToken: String) throws {
        print("🔐 [AUTH] Storing tokens to keychain...")
        print("🔐 [AUTH] AccessToken length: \(accessToken.count)")
        print("🔐 [AUTH] RefreshToken length: \(refreshToken.count)")
        
        keychain[accessTokenKey] = accessToken
        keychain[refreshTokenKey] = refreshToken
        
        // Verify storage
        let storedAccessToken = keychain[accessTokenKey]
        let storedRefreshToken = keychain[refreshTokenKey]
        print("🔐 [AUTH] Verification - AccessToken stored: \(storedAccessToken != nil)")
        print("🔐 [AUTH] Verification - RefreshToken stored: \(storedRefreshToken != nil)")
    }
    
    private func setCurrentUser(_ user: User) async {
        print("🔐 [AUTH] Setting current user...")
        print("🔐 [AUTH] User ID: \(user.id), Email: \(user.email)")
        
        currentUser = user
        isLoggedIn = true
        
        // Store user data
        do {
            let userData = try JSONEncoder().encode(user)
            keychain[data: userKey] = userData
            print("🔐 [AUTH] User data stored to keychain successfully")
        } catch {
            print("❌ [AUTH] Failed to encode/store user data: \(error)")
        }
        
        print("🔐 [AUTH] isLoggedIn set to: \(isLoggedIn)")
    }
    
    private func loadStoredAuth() {
        // Check if we have stored tokens
        guard let _ = keychain[accessTokenKey],
              let _ = keychain[refreshTokenKey] else {
            isLoggedIn = false
            return
        }
        
        // Load stored user data
        if let userData = keychain[data: userKey],
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isLoggedIn = true
        } else {
            // We have tokens but no user data, mark as logged in but user will be fetched when needed
            isLoggedIn = true
        }
    }
    
    private func clearStoredAuth() {
        print("🔐 [AUTH] Clearing keychain tokens...")
        keychain[accessTokenKey] = nil
        keychain[refreshTokenKey] = nil
        keychain[data: userKey] = nil
        
        print("🔐 [AUTH] Clearing current user and login state...")
        currentUser = nil
        isLoggedIn = false
        
        // --- FIX: CLEAR ALL LOCAL DATA ON LOGOUT ---
        // This is crucial to prevent stale data from one user's session
        // causing errors for the next user who logs in on the same device.
        print("🔐 [AUTH] Clearing all local Core Data...")
        DataManager.shared.clearAllData()
        print("🗑️ [AUTH] Cleared all local Core Data on logout.")
        
        // Verify clearing
        let remainingAccessToken = keychain[accessTokenKey]
        let remainingRefreshToken = keychain[refreshTokenKey]
        print("🔐 [AUTH] Verification - AccessToken cleared: \(remainingAccessToken == nil)")
        print("🔐 [AUTH] Verification - RefreshToken cleared: \(remainingRefreshToken == nil)")
        print("🔐 [AUTH] Verification - isLoggedIn: \(isLoggedIn)")
        print("🔐 [AUTH] Verification - currentUser: \(currentUser?.email ?? "nil")")
    }
}

// MARK: - Request/Response Models

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let user: RegisterUserData
}

struct RegisterUserData: Codable {
    let email: String
    let password: String
    let passwordConfirmation: String
    
    enum CodingKeys: String, CodingKey {
        case email, password
        case passwordConfirmation = "password_confirmation"
    }
}

struct RefreshRequest: Codable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct AuthResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
}

struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
}

struct LogoutResponse: Codable {
    let message: String
}

struct EmptyBody: Codable {}

// MARK: - Legacy models - use APIModels.swift versions for new code

// MARK: - User Model

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let createdAt: String
    let interests: [String]?
    
    var needsOnboarding: Bool {
        return interests?.isEmpty ?? true
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noRefreshToken
    case keychainError(Error)
    case invalidCredentials
    case networkError(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .keychainError:
            return "Keychain error occurred"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError(_):
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}