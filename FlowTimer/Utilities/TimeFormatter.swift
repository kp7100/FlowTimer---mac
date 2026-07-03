import Foundation

enum TimeFormatter {
    static func format(seconds: Int) -> String {
        let maxSeconds = max(0, seconds)
        let minutes = maxSeconds / 60
        let remainingSeconds = maxSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
