import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct PresetBannerView: View {
    let preset: ProjectPresetInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // Preset icon
            Image(systemName: preset.iconName)
                .font(.title2)
                .foregroundColor(ColorTheme.primaryAccent)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                // "Guided Interview" label
                Text("Guided Interview")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ColorTheme.secondaryText)
                
                // Preset title
                Text(preset.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTheme.primaryText)
            }
            
            Spacer()
            
            // Optional category badge
            Text(preset.category)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ColorTheme.primaryAccent.opacity(0.1))
                .foregroundColor(ColorTheme.primaryAccent)
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    ColorTheme.primaryAccent.opacity(0.03),
                    ColorTheme.primaryAccent.opacity(0.08)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorTheme.primaryAccent.opacity(0.2), lineWidth: 0.5)
        )
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 16) {
        PresetBannerView(preset: ProjectPresetInfo(
            title: "Finding Resilience",
            iconName: "heart.fill",
            category: "Personal Growth"
        ))
        
        PresetBannerView(preset: ProjectPresetInfo(
            title: "Career Journey",
            iconName: "briefcase.fill",
            category: "Professional"
        ))
        
        PresetBannerView(preset: ProjectPresetInfo(
            title: "Family Stories",
            iconName: "house.fill",
            category: "Family"
        ))
    }
    .padding()
    .background(ColorTheme.primaryBackground)
}