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
        let completed = sessions.filter { $0.coreWorkCompleted }
        guard !completed.isEmpty else { return 0 }
        let sum = completed.reduce(0) { $0 + $1.duration }
        return sum / Double(completed.count)
    }
}
