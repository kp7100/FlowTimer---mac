import Foundation
import Observation

struct DailyGoalProgress {
    let title: String
    let currentValue: Double
    let targetValue: Double
    let filledDots: Int
    let totalDots: Int
    let isCompleted: Bool
    let displayText: String
}

@MainActor
@Observable
final class GoalManager {
    static let shared = GoalManager()
    
    private var historyManager = HistoryManager.shared
    private var settingsManager = SettingsManager.shared
    
    func progress(activeRecord: SessionRecord?) -> DailyGoalProgress {
        let settings = settingsManager.settings
        
        let target = settings.goalFocusTime
        
        let calendar = Calendar.current
        let todayInterval = calendar.dateInterval(of: .day, for: Date())!
        let compInterval = calendar.comparisonInterval(of: .day, for: todayInterval)
        
        let stats = StatisticsStore.shared.getStats(
            for: .day,
            interval: todayInterval,
            comparisonInterval: compInterval,
            goalFocusTime: target,
            activeRecord: activeRecord
        )
        
        let current = stats.totalFocusTime
        
        let fraction = target > 0 ? current / target : 0
        let filled = min(6, Int(fraction * 6.0))
        let completed = current >= target
        
        let display = completed ? "\(TimeFormatter.formatForStats(seconds: current)) / \(TimeFormatter.formatForStats(seconds: target)) ✓" : "\(TimeFormatter.formatForStats(seconds: current)) / \(TimeFormatter.formatForStats(seconds: target))"
        
        return DailyGoalProgress(
            title: "Today's Goal",
            currentValue: current,
            targetValue: target,
            filledDots: completed ? 6 : filled,
            totalDots: 6,
            isCompleted: completed,
            displayText: display
        )
    }
}
