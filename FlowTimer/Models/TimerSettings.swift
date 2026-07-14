import Foundation

struct TimerSettings: Codable, Equatable {
    var workDuration: Int = 25 * 60
    var shortBreakDuration: Int = 5 * 60
    var longBreakDuration: Int = 15 * 60
    var sessionsPerCycle: Int = 4
    
    var flowExtensionLimit: Int? = nil
    var autoStartWork: Bool = true
    
    var launchAtLogin: Bool = false
    var focusTaskResetHour: Int = 0 // Valid range 0-4
    var showTodaysFocus: Bool = true
    
    var selectedTagId: UUID? = nil
    
    var goalsEnabled: Bool = true
    var goalFocusTime: TimeInterval = 3 * 3600
}
