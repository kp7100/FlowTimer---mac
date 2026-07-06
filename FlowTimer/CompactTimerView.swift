import SwiftUI

struct CompactTimerView: View {
    @Bindable var timerManager: TimerManager
    @State private var isHoveringWindow = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 8) {
                // Row 1: Controls & Session Title
                HStack(spacing: 8) {
                    WindowControlsView(isHoveringWindow: isHoveringWindow, showMiniButton: false)
                    
                    Text(timerManager.sessionTitle.isEmpty ? "Flow" : timerManager.sessionTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer()
                }
                .padding(.top, 14)
                .padding(.horizontal, 14)
                
                // Row 2: Timer, Dots & Play Button
                HStack(alignment: .center) {
                    VStack(alignment: .center, spacing: 4) {
                        Text(timerManager.remainingTimeFormatted)
                            .font(.system(size: 48, weight: .regular, design: .default))
                            .monospacedDigit()
                        
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
                .padding(.bottom, 20)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .frame(width: 250)
        .background(Color(NSColor.windowBackgroundColor).ignoresSafeArea())
        .background(MiniWindowAccessorView())
        .onHover { hover in
            isHoveringWindow = hover
        }
    }
}

struct MiniWindowAccessorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            if let window = nsView.window, WindowManager.shared.miniWindow != window {
                WindowManager.shared.miniWindow = window
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
        }
    }
}
