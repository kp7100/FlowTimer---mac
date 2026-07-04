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
            
            // Dots
            HStack(spacing: 12) {
                ForEach(1...timerManager.totalSessions, id: \.self) { index in
                    Circle()
                        .fill(index <= timerManager.currentSession ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .scaleEffect(index == timerManager.currentSession ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: timerManager.currentSession)
                }
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
