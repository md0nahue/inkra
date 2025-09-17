import Foundation

enum QuestionState: Equatable {
    case readyToRecord
    case recorded
    case skipped
    case recordingActive
}