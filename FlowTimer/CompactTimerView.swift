import SwiftUI

struct CompactTimerView: View {
    @Bindable var timerManager: TimerManager
    @State private var isHoveringWindow = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Core centered layout
            HStack(spacing: 0) {
                // Flexible left margin to optically center the timer block
                Spacer()
                
                // Unified Hero Block
                VStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: -4) {
                        InlineEditableTitle(
                            title: $timerManager.sessionTitle,
                            fontSize: 14,
                            fontWeight: .bold,
                            alignment: .leading,
                            frameAlignment: .leading
                        )
                        .padding(.leading, 22) // Shift text right and prevent background from bleeding under Close button
                        .offset(y: -4) // Optically align baseline
                        
                        ZStack(alignment: .center) {
                            Text("+00:00")
                                .font(.system(size: 48, weight: .regular, design: .default))
                                .monospacedDigit()
                                .hidden()
                            
                            Text(timerManager.remainingTimeFormatted)
                                .font(.system(size: 48, weight: .regular, design: .default))
                                .monospacedDigit()
                        }
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    // Slightly tighter dot spacing allows 10 sessions to fit safely
                    // Progress
                    SessionProgressView(timerManager: timerManager, dotSize: 10, spacing: 6)
                        .padding(.top, 4)
                        .offset(x: 3) // Optically center beneath the timer's bounding box
                }
                
                Spacer()
                
                // Play button safely anchored to the right margin
                PlayPauseButton(timerManager: timerManager, size: 44, iconSize: .system(size: 18, weight: .semibold), isMiniTimer: true)
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
            WindowControlsView(isHoveringWindow: isHoveringWindow, showMiniButton: false, onClose: {
                WindowManager.shared.hideMiniTimer()
            })
            .padding(.top, 12)
            .padding(.leading, 12)
        }
        .frame(width: 220, height: 112)
        .fixedSize()
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

