import SwiftUI

struct CompactTimerView: View {
    @Bindable var timerManager: TimerManager
    @State private var isHoveringWindow = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 8) {
                // Row 1: Controls & Session Title
                HStack(spacing: 8) {
                    WindowControlsView(isHoveringWindow: isHoveringWindow, showMiniButton: false, onClose: {
                        WindowManager.shared.hideMiniTimer()
                    })
                        .padding(.top, 2)
                    
                    InlineEditableTitle(
                        title: $timerManager.sessionTitle,
                        fontSize: 14,
                        fontWeight: .bold,
                        alignment: .leading,
                        frameAlignment: .leading
                    )
                    
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.horizontal, 14)
                
                // Row 2: Timer, Dots & Play Button
                HStack(alignment: .center) {
                    VStack(alignment: .center, spacing: 4) {
                        ZStack(alignment: .leading) {
                            Text("+00:00")
                                .font(.system(size: 48, weight: .regular, design: .default))
                                .monospacedDigit()
                                .hidden()
                            
                            Text(timerManager.remainingTimeFormatted)
                                .font(.system(size: 48, weight: .regular, design: .default))
                                .monospacedDigit()
                        }
                        
                        if SettingsManager.shared.settings.goalsEnabled {
                            GoalProgressView(progress: GoalManager.shared.progress, showTitle: false, showText: false, dotSize: 10, spacing: 8)
                        } else {
                            SessionProgressView(currentSession: timerManager.currentSession, totalSessions: timerManager.totalSessions, dotSize: 10, spacing: 8)
                        }
                    }
                    
                    Spacer()
                    
                    PlayPauseButton(timerManager: timerManager, size: 44, iconSize: .system(size: 18, weight: .semibold), isMiniTimer: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .frame(width: 290)
        .fixedSize(horizontal: false, vertical: true)
        .ignoresSafeArea()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .onHover { hover in
            isHoveringWindow = hover
        }
    }
}

