import SwiftUI

struct MenuBarPopoverView: View {
    @Bindable var timerManager: TimerManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        VStack(spacing: 16) {
            // Title and Session Info
            VStack(spacing: 4) {
                Text(timerManager.sessionTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("Session \(timerManager.currentSession) of \(timerManager.totalSessions)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Timer Display
            Text(timerManager.remainingTimeFormatted)
                .font(.system(size: 48, weight: .light, design: .default))
                .monospacedDigit()
            
            // Dots
            HStack(spacing: 8) {
                ForEach(1...timerManager.totalSessions, id: \.self) { index in
                    Circle()
                        .fill(index <= timerManager.currentSession ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Phase Text
            Text(phaseText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Controls
            VStack(spacing: 0) {
                Button(action: {
                    if timerManager.isRunning {
                        timerManager.pause()
                    } else {
                        timerManager.start()
                    }
                }) {
                    Text(timerManager.isRunning ? "Pause" : "Play")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                
                Button(action: {
                    openWindow(id: "mainWindow")
                }) {
                    Text("Open Main Window")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                
                Button(action: {
                    openSettings()
                }) {
                    Text("Settings")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                
                Divider()
                    .padding(.vertical, 4)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(width: 250)
    }
    
    private var phaseText: String {
        switch timerManager.phase {
        case .work: return "Work"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        case .flowExtension: return "Flow Extension"
        }
    }
}
