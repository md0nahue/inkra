//
//  ContentView.swift
//  Inkra
//
//  Created by Magnus Fremont on 7/14/25.
//
import SwiftUI
import KeychainAccess

@available(iOS 15.0, macOS 11.0, *)
struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var appStateService = AppStateService.shared
    @State private var showPermissionsCheck = false
    @State private var hasCheckedPermissions = false
    
    var body: some View {
        Group {
            if authService.isLoggedIn {
                if authService.currentUser?.needsOnboarding == true {
                    OnboardingInterestsView {
                        // After onboarding, show permissions check
                        showPermissionsCheck = true
                    }
                } else if showPermissionsCheck && !hasCheckedPermissions {
                    PermissionsCheckView {
                        showPermissionsCheck = false
                        hasCheckedPermissions = true
                    }
                } else {
                    HomeView()
                }
            } else {
                AuthView()
            }
        }
        .onChange(of: authService.isLoggedIn) { isLoggedIn in
            if isLoggedIn && authService.currentUser?.needsOnboarding != true {
                // User logged in and doesn't need onboarding - check permissions
                showPermissionsCheck = true
                hasCheckedPermissions = false
            } else if !isLoggedIn {
                // User logged out - reset permission check state
                showPermissionsCheck = false
                hasCheckedPermissions = false
            }
        }
        .toast(
            isPresented: $appStateService.showSessionExpiredToast,
            message: appStateService.sessionExpiredMessage,
            duration: 4.0
        )
    }
}

#Preview {
    ContentView()
}
