import Foundation

enum TimeFormatter {
    static func format(seconds: Int) -> String {
        let maxSeconds = max(0, seconds)
        let minutes = maxSeconds / 60
        let remainingSeconds = maxSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    static func formatForStats(seconds: TimeInterval) -> String {
        let maxSeconds = Int(max(0, seconds))
        let hours = maxSeconds / 3600
        let minutes = (maxSeconds % 3600) / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}
