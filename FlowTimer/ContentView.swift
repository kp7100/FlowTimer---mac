//
//  ContentView.swift
//  FlowTimer
//

import SwiftUI

struct ContentView: View {
    @State private var timerManager = TimerManager()
    
    @State private var sessionTitle: String = "Session 1"
    @State private var currentSession: Int = 1
    @State private var totalSessions: Int = 4
    
    var body: some View {
        VStack(spacing: 24) {
            // Editable Title
            HStack(spacing: 4) {
                TextField("Session Title", text: $sessionTitle)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
                
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
            
            // Session Info
            Text("Session \(currentSession) of \(totalSessions)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Timer Display
            Text(timerManager.remainingTimeFormatted)
                .font(.system(size: 72, weight: .light, design: .default))
                .monospacedDigit()
                .padding(.vertical, -10)
            
            // Dots
            HStack(spacing: 12) {
                ForEach(1...totalSessions, id: \.self) { index in
                    Circle()
                        .fill(index <= currentSession ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .scaleEffect(index == currentSession ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentSession)
                }
            }
            
            // Controls
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
    }
}

#Preview {
    ContentView()
}
