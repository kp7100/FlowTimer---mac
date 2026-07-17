import SwiftUI

enum DotState {
    case empty
    case half
    case full
}

struct SessionDotView: View {
    let state: DotState
    let size: CGFloat
    @Environment(\.ambientTheme) var theme

    var body: some View {
        ZStack {
            // Background (empty state)
            Circle()
                .fill(theme.inactiveDotColor)
                .frame(width: size, height: size)

            if state == .full {
                Circle()
                    .fill(theme.activeDotColor)
                    .frame(width: size, height: size)
            } else if state == .half {
                // Left half filled — indicates "currently working on this segment"
                Circle()
                    .fill(theme.activeDotColor)
                    .frame(width: size, height: size)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle().frame(width: size / 2, height: size)
                            Color.clear.frame(width: size / 2, height: size)
                        }
                    )
            }
        }
    }
}

struct SessionProgressView: View {
    var timerManager: TimerManager
    var dotSize: CGFloat = 10
    var spacing: CGFloat = 12

    /// Compute the display state for a given dot index.
    ///
    /// Dots represent work-segment boundaries, not Focus session counts.
    /// `cycleCompletedSegments` only changes when a Focus session completes or
    /// a Flow session ends — never on every timer tick. This keeps dot transitions
    /// coarse and intentional rather than continuously animated.
    ///
    /// Three states:
    ///   ● (full)  — this segment's worth of work is complete
    ///   ◐ (half)  — the user is currently working toward this segment (not proportional)
    ///   ○ (empty) — not yet started
    private func dotState(for index: Int) -> DotState {
        // During Flow Extension, cycleDisplayedSegments includes live elapsed
        // seconds so dots advance as boundaries are crossed mid-Flow.
        // Outside Flow it equals cycleCompletedSegments exactly.
        let completed = timerManager.cycleDisplayedSegments  // clamped to [0, sessionsPerCycle]
        let isActive = timerManager.state != .idle &&
                       (timerManager.phase == .work || timerManager.phase == .flowExtension)

        if index < completed {
            return .full
        }
        // Show half only when the user is actively working on this segment
        // AND the cycle isn't already complete (prevents a stray ◐ beyond the last dot).
        if index == completed && isActive && completed < timerManager.totalSessions {
            return .half
        }
        return .empty
    }

    var body: some View {
        HStack(spacing: spacing) {
            let total = max(1, timerManager.totalSessions)
            ForEach(0..<total, id: \.self) { index in
                SessionDotView(state: dotState(for: index), size: dotSize)
                    // Animate when a segment boundary is crossed.
                    // cycleDisplayedSegments includes live Flow time, so this
                    // fires at boundaries mid-Flow as well as at Focus completion.
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: timerManager.cycleDisplayedSegments)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: timerManager.phase)
            }
        }
    }
}
