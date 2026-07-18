import SwiftUI

struct CompactTimerView: View {
    @Bindable var timerManager: TimerManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHoveringWindow = false
    
    private var currentTheme: AmbientTheme {
        AmbientTheme.current(for: timerManager.phase, isDarkMode: colorScheme == .dark)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Core centered layout
            HStack(spacing: 0) {
                // Flexible left margin to optically center the timer block
                Spacer()
                
                // Unified Hero Block
                VStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: -4) {
                        SharedSessionTitleView(
                            timerManager: timerManager,
                            fontSize: 16,
                            fontWeight: .semibold,
                            alignment: .leading,
                            frameAlignment: .leading
                        )
                        .padding(.leading, isHoveringWindow ? 22 : 0) // Shift text right to accommodate close button on hover
                        .padding(.trailing, -45) // Allow title to use empty space above the play button without expanding the VStack, but leave breathing room on the right
                        .offset(y: -4) // Optically align baseline
                        .animation(.easeInOut(duration: 0.2), value: isHoveringWindow)
                        
                        ZStack(alignment: .center) {
                            Text("00:00")
                                .font(.system(size: 40, weight: .medium, design: .default))
                                .monospacedDigit()
                                .hidden()
                            
                            Text(timerManager.remainingTimeFormatted)
                                .font(.system(size: 40, weight: .medium, design: .default))
                                .monospacedDigit()
                                .foregroundColor(currentTheme.timerTextColor)
                        }
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    // Slightly tighter dot spacing allows 10 sessions to fit safely
                    // Progress
                    SessionProgressView(timerManager: timerManager, dotSize: 10, spacing: 5)
                        .padding(.top, 4)
                }
                
                Spacer()
                
                // Play button safely anchored to the right margin
                PlayPauseButton(timerManager: timerManager, size: 44, iconSize: .system(size: 22, weight: .light), isMiniTimer: true)
                    .padding(.trailing, 16)
                    .offset(y: 5) // Optically center to the Timer text rather than the VStack bounds
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            
            // Absolute top-left corner for window controls (margins)
            // Rendered last in ZStack so it receives clicks above the HStack's onTapGesture
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                
                WindowControlsView(isHoveringWindow: isHoveringWindow, showMiniButton: false, disableAppearanceAnimation: true, onClose: {
                    WindowManager.shared.hideMiniTimer()
                })
                .padding(.top, 8)
                .padding(.leading, 8)
            }
            .onHover { hover in
                isHoveringWindow = hover
            }
        }
        .frame(width: 210, height: 105)
        .ignoresSafeArea()
        .flowModeTransition(timerManager: timerManager, isDarkMode: colorScheme == .dark)
        .sessionRecoveryTransition(timerManager: timerManager, isDarkMode: colorScheme == .dark, isCompactMode: true)
    }
}

