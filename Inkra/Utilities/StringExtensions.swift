import Foundation

extension String {
    var isEmoji: Bool {
        return self.unicodeScalars.contains { scalar in
            scalar.properties.isEmoji
        }
    }
}

// Global function for backward compatibility
func isEmoji(_ string: String) -> Bool {
    return string.isEmoji
}