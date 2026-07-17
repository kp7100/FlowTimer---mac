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
    
    static func formatCompactCycleDuration(seconds: Int) -> String {
        let maxSeconds = max(0, seconds)
        let minutes = maxSeconds / 60
        let h = minutes / 60
        let m = minutes % 60
        
        if h > 0 {
            if m > 0 {
                return String(format: "%dh%02d", h, m)
            } else {
                return "\(h)h"
            }
        } else {
            return "\(m)m"
        }
    }
}
