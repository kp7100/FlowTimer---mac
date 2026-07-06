//
//  ContentView.swift
//  FlowTimer
//

import SwiftUI

struct ContentView: View {
    @Bindable var timerManager: TimerManager
    @Bindable var settingsManager = SettingsManager.shared
    @Bindable var tagManager = TagManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            
            // Metadata Row
            HStack {
                Text("Session \(timerManager.currentSession)/\(timerManager.totalSessions)")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let activeTag = timerManager.activeTag, (timerManager.phase == .work || timerManager.phase == .flowExtension) {
                    Menu {
                        Picker("Selected Tag", selection: $settingsManager.settings.selectedTagId) {
                            Text("None").tag(UUID?.none)
                            Divider()
                            ForEach(tagManager.tags) { tag in
                                Text(tag.name).tag(Optional(tag.id))
                            }
                        }
                    } label: {
                        Text(activeTag)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
            
            // Editable Title
            InlineEditableTitle(title: $timerManager.sessionTitle)
            
            // Timer Display
            Text(timerManager.remainingTimeFormatted)
                .font(.system(size: 72, weight: .regular, design: .default))
                .monospacedDigit()
                .padding(.vertical, -4)
            
            // Progress Indicators
            if SettingsManager.shared.settings.goalsEnabled {
                GoalProgressView(progress: GoalManager.shared.progress)
            } else {
                SessionProgressView(currentSession: timerManager.currentSession, totalSessions: timerManager.totalSessions)
            }
            
            Spacer()
            
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
                HStack(spacing: 12) {
                    Color.clear.frame(width: 32, height: 32) // Balance placeholder
                    
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
                    
                    Button(action: {
                        withAnimation {
                            timerManager.skipCurrentPhase()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 24)
            }
            
        }
        .onChange(of: settingsManager.settings.selectedTagId) { _, _ in
            timerManager.settingsDidChange()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .frame(width: 380, height: 320)
        // Clean white background behavior
        .background(Color(NSColor.windowBackgroundColor).ignoresSafeArea())
        .background(WindowAccessorView())
    }
}

struct GoalProgressView: View {
    let progress: DailyGoalProgress
    var showTitle: Bool = true
    var dotSize: CGFloat = 10
    var spacing: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 6) {
            if showTitle {
                Text(progress.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressDotsView(totalDots: progress.totalDots, filledDots: progress.filledDots, dotSize: dotSize, spacing: spacing)
            
            Text(progress.displayText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct SessionProgressView: View {
    let currentSession: Int
    let totalSessions: Int
    var dotSize: CGFloat = 10
    var spacing: CGFloat = 12
    
    var body: some View {
        ProgressDotsView(totalDots: totalSessions, filledDots: currentSession, activeDotIndex: currentSession - 1, dotSize: dotSize, spacing: spacing)
    }
}

struct ProgressDotsView: View {
    let totalDots: Int
    let filledDots: Int
    var activeDotIndex: Int? = nil
    var dotSize: CGFloat = 10
    var spacing: CGFloat = 12
    
    var body: some View {
        HStack(spacing: spacing) {
            let validTotal = max(1, totalDots)
            ForEach(0..<validTotal, id: \.self) { index in
                Circle()
                    .fill(index < filledDots ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(index == activeDotIndex ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: filledDots)
            }
        }
    }
}

struct WindowAccessorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            if let window = nsView.window, WindowManager.shared.mainWindow != window {
                WindowManager.shared.mainWindow = window
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
    }
}

struct InlineEditableTitle: View {
    @Binding var title: String
    
    @State private var isEditing = false
    @State private var isHovering = false
    @State private var draftText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            if isEditing {
                TextField("", text: $draftText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .medium))
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .onSubmit {
                        commit()
                    }
                    .onExitCommand {
                        cancel()
                    }
                    .onChange(of: isFocused) { _, newValue in
                        if !newValue && isEditing {
                            commit()
                        }
                    }
            } else {
                Text(title.isEmpty ? "What's your focus?" : title)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(title.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draftText = title
                        isEditing = true
                        Task {
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            isFocused = true
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(isHovering && !isEditing ? 0.06 : 0))
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hover
            }
        }
    }
    
    private func commit() {
        title = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditing = false
        isFocused = false
    }
    
    private func cancel() {
        isEditing = false
        isFocused = false
    }
}

#Preview {
    ContentView(timerManager: TimerManager())
}
