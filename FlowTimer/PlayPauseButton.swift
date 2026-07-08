import SwiftUI

struct PlayPauseButton: View {
    @Bindable var timerManager: TimerManager
    var size: CGFloat = 60
    var iconSize: Font = .title2
    var isMiniTimer: Bool = false
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        Button(action: {
            withAnimation {
                if isMiniTimer && timerManager.phase == .flowExtension {
                    timerManager.takeBreak()
                } else {
                    if timerManager.isRunning {
                        timerManager.pause()
                    } else {
                        timerManager.start()
                    }
                }
            }
        }) {
            if isMiniTimer && timerManager.phase == .flowExtension {
                Image(systemName: WellnessIconProvider.icon(for: timerManager.flowWellnessState))
                    .font(iconSize)
                    .foregroundColor(theme.buttonForeground)
                    .frame(width: size, height: size)
                    .background(theme.buttonBackground)
                    .clipShape(Circle())
            } else {
                Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                    .font(iconSize)
                    .foregroundColor(timerManager.phase == .work ? theme.accentColor : theme.buttonForeground)
                    .frame(width: size, height: size)
                    .background(timerManager.phase == .work ? theme.accentColor.opacity(0.15) : theme.buttonBackground)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
    }
}
