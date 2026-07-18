import Foundation

struct PeriodStats {
    let totalFocusTime: TimeInterval
    let comparisonMinutes: Int
    let longestSession: TimeInterval
    let averageSessionLength: TimeInterval
    let completedSessions: Int
    let pauseCount: Int
    let averagePausesPerSession: Double
    let topTags: [(String, TimeInterval)]
    let daysMeetingGoal: Int
    let totalDaysInPeriod: Int
    let focusSessions: [ContinuousSession] // Needed for exact intra-day charts in Day view
}
