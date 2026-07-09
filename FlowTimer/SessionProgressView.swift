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
                // Left half filled
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
    
    private func dotState(for index: Int) -> DotState {
        if timerManager.phase == .work {
            if index < timerManager.currentSession - 1 { return .full }
            if index == timerManager.currentSession - 1 { 
                return timerManager.state == .idle ? .empty : .half 
            }
            return .empty
        } else {
            if index <= timerManager.currentSession - 1 { return .full }
            return .empty
        }
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            let total = max(1, timerManager.totalSessions)
            ForEach(0..<total, id: \.self) { index in
                SessionDotView(state: dotState(for: index), size: dotSize)
                    .scaleEffect(index == timerManager.currentSession - 1 ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: timerManager.currentSession)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: timerManager.phase)
            }
        }
    }
}
