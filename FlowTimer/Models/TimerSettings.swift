import Foundation

enum DailyGoalType: String, Codable {
    case focusTime
    case sessions
}

struct TimerSettings: Codable, Equatable {
    var workDuration: Int = 25 * 60
    var shortBreakDuration: Int = 5 * 60
    var longBreakDuration: Int = 15 * 60
    var sessionsPerCycle: Int = 4
    
    var autoStartBreaks: Bool = true
    var autoStartWork: Bool = true
    
    var launchAtLogin: Bool = false
    
    var selectedTagId: UUID? = nil
    
    var goalsEnabled: Bool = true
    var goalType: DailyGoalType = .focusTime
    var goalFocusTime: TimeInterval = 3 * 3600
    var goalSessions: Int = 6
}
