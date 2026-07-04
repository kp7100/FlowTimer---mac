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
    
    var progress: DailyGoalProgress {
        let settings = settingsManager.settings
        
        if settings.goalType == .focusTime {
            let current = historyManager.focusTimeToday() + historyManager.flowExtensionToday()
            let target = settings.goalFocusTime
            let fraction = target > 0 ? current / target : 0
            let filled = min(6, Int(fraction * 6.0))
            let completed = current >= target
            
            let display = completed ? "Goal Completed ✓" : "\(TimeFormatter.formatForStats(seconds: current)) / \(TimeFormatter.formatForStats(seconds: target))"
            
            return DailyGoalProgress(
                title: "Today's Goal",
                currentValue: current,
                targetValue: target,
                filledDots: completed ? 6 : filled,
                totalDots: 6,
                isCompleted: completed,
                displayText: display
            )
        } else {
            let currentInt = historyManager.completedWorkSessionsToday()
            let targetInt = settings.goalSessions
            let filled = min(targetInt, currentInt)
            let completed = currentInt >= targetInt
            
            let display = completed ? "\(currentInt) / \(targetInt) Sessions ✓" : "\(currentInt) / \(targetInt) Sessions"
            
            return DailyGoalProgress(
                title: "Today's Goal",
                currentValue: Double(currentInt),
                targetValue: Double(targetInt),
                filledDots: filled,
                totalDots: targetInt,
                isCompleted: completed,
                displayText: display
            )
        }
    }
}
