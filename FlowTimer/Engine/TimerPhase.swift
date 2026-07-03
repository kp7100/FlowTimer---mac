import Foundation

enum TimerPhase: Sendable {
    case work
    case shortBreak
    case longBreak
    case flowExtension
}

extension TimerPhase: Equatable {
    nonisolated static func == (lhs: TimerPhase, rhs: TimerPhase) -> Bool {
        switch (lhs, rhs) {
        case (.work, .work), (.shortBreak, .shortBreak), (.longBreak, .longBreak), (.flowExtension, .flowExtension): return true
        default: return false
        }
    }
}
