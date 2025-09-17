import SwiftUI

struct MarkdownRenderer {
    static func render(_ markdownText: String) -> AttributedString {
        do {
            // Use iOS 15+ AttributedString markdown parsing
            let attributedString = try AttributedString(markdown: markdownText)
            return attributedString
        } catch {
            // If markdown parsing fails, return as plain text
            return AttributedString(markdownText)
        }
    }
}

// SwiftUI Text extension for easy markdown rendering
extension Text {
    init(markdown: String) {
        let attributedString = MarkdownRenderer.render(markdown)
        self.init(attributedString)
    }
}