import Foundation

enum TimerPhase: String, Sendable, Codable {
    case work
    case shortBreak
    case longBreak
    case flowExtension
}
