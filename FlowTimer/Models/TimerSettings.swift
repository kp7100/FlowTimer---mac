import Foundation

struct TimerSettings: Codable, Equatable {
    var workDuration: Int = 25 * 60
    var shortBreakDuration: Int = 5 * 60
    var longBreakDuration: Int = 15 * 60
    var sessionsPerCycle: Int = 4
    
    var autoStartBreaks: Bool = true
    var autoStartWork: Bool = true
}
