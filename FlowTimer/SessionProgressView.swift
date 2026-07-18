import SwiftUI

enum DotState: Equatable {
    case inactive
    case activeEmpty
    case activeHalf
    case completed
}

struct SessionDotView: View {
    let state: DotState
    let size: CGFloat
    @Environment(\.ambientTheme) var theme

    private var symbolName: String {
        switch state {
        case .inactive: return "circle"
        case .activeEmpty: return "capsule"
        case .activeHalf: return "capsule.lefthalf.filled"
        case .completed: return "circle.fill"
        }
    }

    private var color: Color {
        state == .inactive ? theme.inactiveDotColor : theme.activeDotColor
    }

    var body: some View {
        Image(systemName: symbolName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: state == .inactive || state == .completed ? size : size * 1.2, weight: .medium))
            .foregroundColor(color)
            .contentTransition(.symbolEffect(.replace))
    }
}

struct SessionProgressView: View {
    var timerManager: TimerManager
    var dotSize: CGFloat = 10
    var spacing: CGFloat = 12

    private enum ProgressThreshold {
        static let half = 0.5
        static let complete = 1.0
    }

    /// Finds the index of the first incomplete milestone.
    private var activeMilestoneIndex: Int? {
        let total = timerManager.totalSessions
        for i in 0..<total {
            if timerManager.progress(forSegment: i) < ProgressThreshold.complete {
                return i
            }
        }
        return nil
    }

    /// Compute the display state for a given dot index based purely on accumulated work.
    ///
    /// - Completed: 100% progress (circle.fill)
    /// - Active (Incomplete):
    ///   - >= 50% progress: ActiveHalf (capsule.lefthalf.filled)
    ///   - < 50% progress: ActiveEmpty (capsule)
    /// - Inactive: 0% progress and not the current active milestone (circle)
    private func dotState(for index: Int) -> DotState {
        let progress = timerManager.progress(forSegment: index)
        
        if progress >= ProgressThreshold.complete {
            return .completed
        }
        
        if index == activeMilestoneIndex {
            let isBreak = timerManager.phase == .shortBreak || timerManager.phase == .longBreak
            if (timerManager.state == .idle || isBreak) && progress == 0 {
                return .inactive
            }
            if progress >= ProgressThreshold.half {
                return .activeHalf
            } else {
                return .activeEmpty
            }
        }
        
        return .inactive
    }

    var body: some View {
        HStack(spacing: spacing) {
            let total = max(1, timerManager.totalSessions)
            ForEach(0..<total, id: \.self) { index in
                let state = dotState(for: index)
                SessionDotView(state: state, size: dotSize)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state)
            }
        }
    }
}
