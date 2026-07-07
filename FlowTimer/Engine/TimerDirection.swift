import Foundation

enum TimerDirection: String, Sendable, Codable {
    case countdown
    case countup
}

extension TimerDirection: Equatable {
    nonisolated static func == (lhs: TimerDirection, rhs: TimerDirection) -> Bool {
        switch (lhs, rhs) {
        case (.countdown, .countdown), (.countup, .countup): return true
        default: return false
        }
    }
}
