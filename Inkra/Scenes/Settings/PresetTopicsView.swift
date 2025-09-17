import SwiftUI

struct PresetTopic: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let category: String
}

@available(iOS 15.0, macOS 11.0, *)
struct PresetTopicsView: View {
    @Environment(\.dismiss) private var dismiss
    let onTopicSelected: (String) -> Void
    
    let presetTopics = [
        PresetTopic(title: "Getting over a breakup", icon: "heart.slash.fill", category: "Relationships"),
        PresetTopic(title: "Looking for new love", icon: "heart.circle.fill", category: "Relationships"),
        PresetTopic(title: "The hardest thing that ever happened to me", icon: "cloud.rain.fill", category: "Life Events"),
        PresetTopic(title: "The best thing that ever happened to me", icon: "star.fill", category: "Life Events"),
        PresetTopic(title: "The funniest thing that ever happened to me", icon: "face.smiling.fill", category: "Life Events"),
        PresetTopic(title: "My biggest achievement", icon: "trophy.fill", category: "Personal Growth"),
        PresetTopic(title: "A time I overcame fear", icon: "shield.fill", category: "Personal Growth"),
        PresetTopic(title: "My dreams and aspirations", icon: "sparkles", category: "Future"),
        PresetTopic(title: "Childhood memories", icon: "figure.child", category: "Memories"),
        PresetTopic(title: "A life-changing decision", icon: "signpost.right.fill", category: "Decisions"),
        PresetTopic(title: "Lessons learned from failure", icon: "arrow.uturn.up", category: "Personal Growth"),
        PresetTopic(title: "My role models and why", icon: "person.2.fill", category: "Inspiration"),
        PresetTopic(title: "What makes me happy", icon: "sun.max.fill", category: "Well-being"),
        PresetTopic(title: "My biggest regret", icon: "arrow.backward.circle.fill", category: "Reflection"),
        PresetTopic(title: "A moment of pure joy", icon: "party.popper.fill", category: "Life Events"),
        PresetTopic(title: "How I've changed over the years", icon: "arrow.triangle.2.circlepath", category: "Personal Growth"),
        PresetTopic(title: "My family story", icon: "house.fill", category: "Family"),
        PresetTopic(title: "Adventures and travels", icon: "airplane", category: "Experiences"),
        PresetTopic(title: "Career journey and ambitions", icon: "briefcase.fill", category: "Career"),
        PresetTopic(title: "Friendships that shaped me", icon: "person.3.fill", category: "Relationships")
    ]
    
    var groupedTopics: [String: [PresetTopic]] {
        Dictionary(grouping: presetTopics, by: { $0.category })
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image("octopus-transparent-background")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                        
                        Text("Interview Ideas")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(ColorTheme.primaryText)
                        
                        Text("Choose a topic to spark your story")
                            .font(.body)
                            .foregroundColor(ColorTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Topics by category
                    ForEach(groupedTopics.keys.sorted(), id: \.self) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category)
                                .font(.headline)
                                .foregroundColor(ColorTheme.secondaryText)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(groupedTopics[category] ?? []) { topic in
                                    Button(action: {
                                        onTopicSelected(topic.title)
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: topic.icon)
                                                .font(.system(size: 24))
                                                .foregroundColor(ColorTheme.primaryAccent)
                                                .frame(width: 40)
                                            
                                            Text(topic.title)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(ColorTheme.primaryText)
                                                .multilineTextAlignment(.leading)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14))
                                                .foregroundColor(ColorTheme.tertiaryText)
                                        }
                                        .padding(16)
                                        .background(ColorTheme.cardBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(ColorTheme.primaryAccent.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Bottom padding
                    Color.clear.frame(height: 40)
                }
            }
            .navigationTitle("Choose a Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .background(ColorTheme.primaryBackground)
        }
    }
}

#Preview {
    PresetTopicsView { topic in
        print("Selected topic: \(topic)")
    }
}