import SwiftUI

struct MenuBarPopoverView: View {
    @Bindable var timerManager: TimerManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private var currentTheme: AmbientTheme {
        AmbientTheme.current(for: timerManager.phase, isDarkMode: colorScheme == .dark)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Top Bar
            HStack(spacing: 12) {
                WindowControlsView(isHoveringWindow: true, showCloseButton: false, onClose: {
                    WindowManager.shared.toggleMiniTimer()
                })
                
                if SettingsManager.shared.settings.goalsEnabled {
                    let progress = GoalManager.shared.progress
                    Text(progress.displayText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(currentTheme.secondaryForegroundColor)
                }
                Spacer()
                
                if timerManager.phase == .work || timerManager.phase == .flowExtension {
                    TagSelectorMenu()
                }
            }
            .padding(.horizontal, 20)
            
            Spacer().frame(height: 8)
            
            // Session Title
            SharedSessionTitleView(
                timerManager: timerManager,
                fontSize: 22,
                fontWeight: .medium,
                alignment: .center,
                frameAlignment: .center
            )
            .padding(.horizontal, 20)
            
            // Timer Display
            Text(timerManager.remainingTimeFormatted)
                .font(.system(size: 72, weight: .regular, design: .default))
                .monospacedDigit()
                .padding(.vertical, -4)
            
            // Session Progress
            SessionProgressView(timerManager: timerManager, dotSize: 10, spacing: 12)
                .padding(.bottom, 12)
            
            // Controls
            if timerManager.phase == .flowExtension {
                HStack(spacing: 16) {
                    PlayPauseButton(timerManager: timerManager, size: 44, iconSize: .title2)
                    
                    Button(action: {
                        withAnimation {
                            timerManager.takeBreak()
                        }
                    }) {
                        Text("Take Break")
                            .font(.subheadline)
                    }
                    .buttonStyle(PrimaryAmbientButtonStyle())
                }
                .padding(.bottom, 16)
            } else {
                HStack(spacing: 12) {
                    Color.clear.frame(width: 32, height: 32) // Balance placeholder
                    
                    PlayPauseButton(timerManager: timerManager, size: 60, iconSize: .title2)
                    
                    Button(action: {
                        withAnimation {
                            timerManager.skipCurrentPhase()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(currentTheme.secondaryForegroundColor)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 16)
            }
            
            Divider()
                .padding(.horizontal, 16)
            
            // Secondary Actions
            VStack(spacing: 4) {
                PopoverMenuItem(title: "Open Main Window") {
                    WindowManager.shared.showMainTimer()
                    dismiss()
                }
                
                PopoverMenuItem(title: "Settings") {
                    dismiss()
                    Task { @MainActor in
                        await Task.yield()
                        WindowManager.shared.showSettingsWindow()
                    }
                }
                
                PopoverMenuItem(title: "Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .padding(.vertical, 16)
        .frame(width: 320)
        .ambientTheme(currentTheme)
    }
}

struct PopoverMenuItem: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(isHovered ? theme.buttonForeground : theme.foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isHovered ? theme.accentColor : Color.clear)
                .cornerRadius(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
