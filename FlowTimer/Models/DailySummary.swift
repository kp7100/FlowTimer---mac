import Foundation

struct DailySummary: Identifiable, Hashable {
    var id: Date { date }
    let date: Date // Represents the start of the day
    var totalFocusDuration: TimeInterval
    var completedSessions: Int
    var pauseCount: Int
    var sessions: [ContinuousSession]
    
    // Derived properties useful for aggregations
    var averageSessionLength: TimeInterval {
        completedSessions > 0 ? totalFocusDuration / Double(completedSessions) : 0
    }
}
