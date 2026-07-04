//
//  ContentView.swift
//  FlowTimer
//

import SwiftUI

struct ContentView: View {
    @Bindable var timerManager: TimerManager
    
    var body: some View {
        VStack(spacing: 24) {
            
            // Editable Title
            HStack(spacing: 4) {
                TextField("Session Title", text: $timerManager.sessionTitle)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
                
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
            
            if let activeTag = timerManager.activeTag, (timerManager.phase == .work || timerManager.phase == .flowExtension) {
                Text(activeTag)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(Color.accentColor)
                    .clipShape(Capsule())
            }
            
            // Session Info
            Text("Session \(timerManager.currentSession) of \(timerManager.totalSessions)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Timer Display
            Text(timerManager.remainingTimeFormatted)
                .font(.system(size: 72, weight: .light, design: .default))
                .monospacedDigit()
                .padding(.vertical, -10)
            
            // Progress Indicators
            if SettingsManager.shared.settings.goalsEnabled {
                GoalProgressView(progress: GoalManager.shared.progress)
            } else {
                SessionProgressView(currentSession: timerManager.currentSession, totalSessions: timerManager.totalSessions)
            }
            
            // Controls
            if timerManager.phase == .flowExtension {
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation {
                            if timerManager.isRunning {
                                timerManager.pause()
                            } else {
                                timerManager.start()
                            }
                        }
                    }) {
                        Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation {
                            timerManager.takeBreak()
                        }
                    }) {
                        Text("Take Break")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .frame(height: 44)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 24)
            } else {
                Button(action: {
                    withAnimation {
                        if timerManager.isRunning {
                            timerManager.pause()
                        } else {
                            timerManager.start()
                        }
                    }
                }) {
                    Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(Color.accentColor)
                        .frame(width: 60, height: 60)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
            
        }
        .frame(width: 320, height: 430)
        // Background blur with no borders
        .background(VisualEffectView().ignoresSafeArea())
    }
}

struct GoalProgressView: View {
    let progress: DailyGoalProgress
    
    var body: some View {
        VStack(spacing: 6) {
            Text(progress.title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressDotsView(totalDots: progress.totalDots, filledDots: progress.filledDots)
            
            Text(progress.displayText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct SessionProgressView: View {
    let currentSession: Int
    let totalSessions: Int
    
    var body: some View {
        ProgressDotsView(totalDots: totalSessions, filledDots: currentSession, activeDotIndex: currentSession - 1)
    }
}

struct ProgressDotsView: View {
    let totalDots: Int
    let filledDots: Int
    var activeDotIndex: Int? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            let validTotal = max(1, totalDots)
            ForEach(0..<validTotal, id: \.self) { index in
                Circle()
                    .fill(index < filledDots ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .scaleEffect(index == activeDotIndex ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: filledDots)
            }
        }
    }
}

// Helper to get native NSVisualEffectView for that "ultra thin" glass look
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        Task { @MainActor in
            if let window = nsView.window, WindowManager.shared.mainWindow != window {
                WindowManager.shared.mainWindow = window
            }
        }
    }
}

#Preview {
    ContentView(timerManager: TimerManager())
}
