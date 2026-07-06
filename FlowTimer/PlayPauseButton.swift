import SwiftUI

struct PlayPauseButton: View {
    @Bindable var timerManager: TimerManager
    var size: CGFloat = 60
    var iconSize: Font = .title2
    var isMiniTimer: Bool = false
    
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
                Image(systemName: "cup.and.saucer.fill")
                    .font(iconSize)
                    .foregroundColor(Color.accentColor)
                    .frame(width: size, height: size)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Circle())
            } else {
                Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                    .font(iconSize)
                    .foregroundColor(timerManager.phase == .flowExtension ? .secondary : Color.accentColor)
                    .frame(width: size, height: size)
                    .background((timerManager.phase == .flowExtension ? Color.secondary : Color.accentColor).opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
    }
}
