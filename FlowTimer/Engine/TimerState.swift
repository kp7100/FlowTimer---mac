import Foundation

enum TimerState: Sendable {
    case idle
    case running
    case paused
    case completed
}

extension TimerState: Equatable {
    nonisolated static func == (lhs: TimerState, rhs: TimerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.running, .running), (.paused, .paused), (.completed, .completed): return true
        default: return false
        }
    }
}
