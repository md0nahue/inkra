import SwiftUI

struct MenuView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = AuthService.shared
    @State private var showingAccountSettings = false
    @State private var showingInkra = false
    @State private var showingFeedback = false
    @State private var showingAudioSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Cosmic Lofi background
                ColorTheme.auroraGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header with title
                        VStack(spacing: 16) {
                            Text("Menu")
                                .font(Typography.screenTitle)
                                .foregroundColor(ColorTheme.starlightWhite)
                                .padding(.top, 20)
                        }
                        
                        // Navigation Section
                        MenuSection(title: "Navigate") {
                            MenuButton(
                                title: "AI Interview",
                                icon: "person.2.wave.2",
                                action: { showingInkra = true }
                            )
                            
                        }
                        
                        // Development Tools Section
                        MenuSection(title: "Development Tools") {
                            MenuButton(
                                title: "Font Library",
                                icon: "textformat",
                                navigationDestination: FontListView()
                            )
                        }
                        
                        // Settings Section
                        MenuSection(title: "Settings") {
                            MenuButton(
                                title: "Audio Settings",
                                icon: "speaker.wave.2.fill",
                                action: { showingAudioSettings = true }
                            )
                            
                            MenuButton(
                                title: "Account Settings",
                                icon: "person.circle",
                                action: { showingAccountSettings = true }
                            )
                            
                            MenuButton(
                                title: "Leave App Feedback",
                                icon: "heart.text.square",
                                action: { showingFeedback = true }
                            )
                        }
                        
                        // Logout Section
                        VStack(spacing: 16) {
                            MenuButton(
                                title: "Logout",
                                icon: "arrow.backward.circle",
                                isDestructive: true,
                                action: {
                                    Task {
                                        try? await authService.logout()
                                        dismiss()
                                    }
                                }
                            )
                        }
                        .padding(.top, 20)
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
            .overlay(
                // Done button in top-right
                VStack {
                    HStack {
                        Spacer()
                        Button("Done") {
                            dismiss()
                        }
                        .font(Typography.buttonLabel)
                        .foregroundColor(ColorTheme.dreamyLavender)
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                },
                alignment: .topTrailing
            )
            .sheet(isPresented: $showingAccountSettings) {
                AccountSettingsView()
            }
            .sheet(isPresented: $showingInkra) {
                ProjectListView()
            }
            .sheet(isPresented: $showingFeedback) {
                if #available(iOS 17.0, macOS 11.0, *) {
                    FeedbackView()
                } else {
                    Text("Feedback requires iOS 17 or later")
                        .padding()
                }
            }
            .fullScreenCover(isPresented: $showingAudioSettings) {
                AudioSettingsView()
            }
        }
    }
}

// Menu Section Component
struct MenuSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(Typography.cardTitle)
                .foregroundColor(ColorTheme.starlightWhite)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                content
            }
        }
    }
}

// Menu Button Component
struct MenuButton<Destination: View>: View {
    let title: String
    let icon: String
    let action: (() -> Void)?
    let navigationDestination: Destination?
    let isDestructive: Bool
    
    init(
        title: String,
        icon: String,
        isDestructive: Bool = false,
        action: (() -> Void)? = nil
    ) where Destination == Never {
        self.title = title
        self.icon = icon
        self.action = action
        self.navigationDestination = nil
        self.isDestructive = isDestructive
    }
    
    init(
        title: String,
        icon: String,
        isDestructive: Bool = false,
        navigationDestination: Destination
    ) {
        self.title = title
        self.icon = icon
        self.action = nil
        self.navigationDestination = navigationDestination
        self.isDestructive = isDestructive
    }
    
    var body: some View {
        Group {
            if let destination = navigationDestination {
                NavigationLink(destination: destination) {
                    menuButtonContent
                }
            } else {
                Button(action: action ?? {}) {
                    menuButtonContent
                }
            }
        }
    }
    
    private var menuButtonContent: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isDestructive ? ColorTheme.error : ColorTheme.dreamyLavender)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(Typography.bodyText)
                .foregroundColor(isDestructive ? ColorTheme.error : ColorTheme.starlightWhite)
            
            Spacer()
            
            if navigationDestination != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ColorTheme.moonstoneGrey)
            }
        }
        .padding(20)
        .cosmicLofiCard()
    }
}

#Preview {
    MenuView()
}