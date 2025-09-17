import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct ColorTheme {
    // MARK: - Cosmic Lofi Primary Colors (Backgrounds & Surfaces)
    static let voidPurple = Color(hex: "#100F1C") ?? Color.black  // Primary background
    static let deepIndigo = Color(hex: "#1B1A2E") ?? Color.black  // Secondary gradient background
    static let midnightSlate = Color(hex: "#26243D") ?? Color.secondary  // Cards, entry summaries, modules
    
    static let primaryBackground = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#100F1C") ?? UIColor.black // Void Purple
            : UIColor.systemBackground
    })
    
    static let secondaryBackground = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#1B1A2E") ?? UIColor.darkGray // Deep Indigo
            : UIColor.secondarySystemBackground
    })
    
    static let tertiaryBackground = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#26243D") ?? UIColor.darkGray // Midnight Slate
            : UIColor.tertiarySystemBackground
    })
    
    // MARK: - Cosmic Lofi Accent Colors
    static let dreamyLavender = Color(hex: "#A098E0") ?? Color.purple  // Primary CTA color
    static let sereneBlue = Color(hex: "#92C8D9") ?? Color.blue      // Secondary accent
    static let pastelRose = Color(hex: "#D9AABF") ?? Color.pink      // Tertiary accent
    static let celestialGlow = Color(hex: "#4D4975") ?? Color.gray   // Glow effects
    
    static let primaryAccent = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#A098E0") ?? UIColor.systemBlue // Dreamy Lavender
            : UIColor.systemBlue
    })
    
    static let secondaryAccent = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#92C8D9") ?? UIColor.systemPurple // Serene Blue
            : UIColor.systemPurple
    })
    
    static let tertiaryAccent = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#D9AABF") ?? UIColor.systemPink // Pastel Rose
            : UIColor.systemPink
    })
    
    // MARK: - Cosmic Lofi Text & Iconography Colors
    static let starlightWhite = Color(hex: "#EFEFF5") ?? Color.white  // Primary headings and body text
    static let moonstoneGrey = Color(hex: "#89879A") ?? Color.gray   // Secondary text, placeholder text, inactive icons
    
    static let primaryText = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#EFEFF5") ?? UIColor.label // Starlight White
            : UIColor.label
    })
    
    static let secondaryText = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#89879A") ?? UIColor.secondaryLabel // Moonstone Grey
            : UIColor.secondaryLabel
    })
    
    static let tertiaryText = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#89879A") ?? UIColor.tertiaryLabel // Moonstone Grey
            : UIColor.tertiaryLabel
    })
    
    // MARK: - UI Element Colors
    static let cardBackground = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#26243D") ?? UIColor.darkGray // Midnight Slate
            : UIColor.systemBackground
    })
    
    static let cardBorder = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? (UIColor(hex: "#4D4975") ?? UIColor.systemGray).withAlphaComponent(0.3) // Celestial Glow with opacity
            : UIColor.systemGray5
    })
    
    static let divider = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? (UIColor(hex: "#4D4975") ?? UIColor.systemGray).withAlphaComponent(0.2) // Celestial Glow with opacity
            : UIColor.separator
    })
    
    // MARK: - Status Colors
    static let success = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#92C8D9") ?? UIColor.systemGreen // Serene Blue for success
            : UIColor.systemGreen
    })
    
    static let warning = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: "#D9AABF") ?? UIColor.systemOrange // Pastel Rose for warning
            : UIColor.systemOrange
    })
    
    static let error = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0) // Soft red
            : UIColor.systemRed
    })
    
    // MARK: - Shadow Colors
    static let shadowColor = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.5)
            : UIColor.black.withAlphaComponent(0.1)
    })
    
    // MARK: - Gradient Colors for Aurora Effects
    static var auroraGradient: LinearGradient {
        LinearGradient(
            colors: [voidPurple, deepIndigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var celestialGlowGradient: RadialGradient {
        RadialGradient(
            colors: [celestialGlow.opacity(0.2), Color.clear],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }
}

// MARK: - Typography System
@available(iOS 15.0, macOS 11.0, *)
struct Typography {
    // MARK: - AvenirNext Font Variants
    static func heading(_ size: CGFloat = 28) -> Font {
        .custom("AvenirNext-DemiBold", size: size)
    }
    
    static func body(_ size: CGFloat = 17) -> Font {
        .custom("AvenirNext-Regular", size: size)
    }
    
    static func caption(_ size: CGFloat = 14) -> Font {
        .custom("AvenirNext-Medium", size: size)
    }
    
    // MARK: - Semantic Font Styles
    static let screenTitle = Font.custom("AvenirNext-DemiBold", size: 28)
    static let cardTitle = Font.custom("AvenirNext-DemiBold", size: 20)
    static let buttonLabel = Font.custom("AvenirNext-Regular", size: 17)
    static let bodyText = Font.custom("AvenirNext-Regular", size: 17)
    static let timestamp = Font.custom("AvenirNext-Medium", size: 14)
    static let metadata = Font.custom("AvenirNext-Medium", size: 12)
}

// MARK: - View Modifiers
@available(iOS 15.0, macOS 11.0, *)
struct CosmicLofiCard: ViewModifier {
    let glowEffect: Bool
    
    init(glowEffect: Bool = false) {
        self.glowEffect = glowEffect
    }
    
    func body(content: Content) -> some View {
        content
            .background(ColorTheme.cardBackground)
            .cornerRadius(20) // Generous border radius per style guide
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(ColorTheme.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: ColorTheme.shadowColor, radius: 8, x: 0, y: 4)
            .background(
                // Optional celestial glow effect
                glowEffect ? 
                RoundedRectangle(cornerRadius: 20)
                    .fill(ColorTheme.celestialGlowGradient)
                    .blur(radius: 20)
                    .offset(x: 0, y: 0)
                : nil
            )
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct PillButton: ViewModifier {
    let isPrimary: Bool
    
    init(isPrimary: Bool = true) {
        self.isPrimary = isPrimary
    }
    
    func body(content: Content) -> some View {
        content
            .font(Typography.buttonLabel)
            .foregroundColor(isPrimary ? ColorTheme.starlightWhite : ColorTheme.primaryText)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                isPrimary ? 
                ColorTheme.dreamyLavender : 
                ColorTheme.secondaryAccent
            )
            .cornerRadius(999) // Fully rounded pill shape
            .shadow(color: ColorTheme.shadowColor, radius: 4, x: 0, y: 2)
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct InputField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typography.bodyText)
            .foregroundColor(ColorTheme.primaryText)
            .padding()
            .background(ColorTheme.tertiaryBackground)
            .cornerRadius(12) // Slightly smaller radius for input fields
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTheme.cardBorder, lineWidth: 1)
            )
    }
}

@available(iOS 15.0, macOS 11.0, *)
extension View {
    func cosmicLofiCard(glowEffect: Bool = false) -> some View {
        modifier(CosmicLofiCard(glowEffect: glowEffect))
    }
    
    func pillButton(isPrimary: Bool = true) -> some View {
        modifier(PillButton(isPrimary: isPrimary))
    }
    
    func inputField() -> some View {
        modifier(InputField())
    }
    
    // Legacy support - will be deprecated
    func darkModeCard() -> some View {
        cosmicLofiCard()
    }
}

