import Foundation

struct TranscriptionDetails: Codable {
    let words: [WordTimestamp]
    let duration: TimeInterval?
    let fullText: String
}

struct WordTimestamp: Codable {
    let word: String
    let start: TimeInterval
    let end: TimeInterval
}

