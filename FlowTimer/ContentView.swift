//
//  ContentView.swift
//  FlowTimer
//

import SwiftUI

struct ContentView: View {
    @Bindable var timerManager: TimerManager
    @Bindable var settingsManager = SettingsManager.shared
    @Bindable var tagManager = TagManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    private var currentTheme: AmbientTheme {
        AmbientTheme.current(for: timerManager.phase, isDarkMode: colorScheme == .dark)
    }
    
    @State private var isHoveringWindow = false
    
    var body: some View {
        VStack(spacing: 8) {
            
            // TopBar (Controls + Metadata)
            HStack(spacing: 12) {
                WindowControlsView(isHoveringWindow: isHoveringWindow, onClose: {
                    WindowManager.shared.hideMainTimer()
                })
                
                if SettingsManager.shared.settings.goalsEnabled {
                    let progress = GoalManager.shared.progress
                    Text(progress.displayText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(currentTheme.secondaryForegroundColor)
                        .opacity(isHoveringWindow ? 1 : 0)
                        .animation(.easeInOut(duration: 0.18), value: isHoveringWindow)
                }
                
                Spacer()
                
                if timerManager.phase == .work || timerManager.phase == .flowExtension {
                    TagSelectorMenu()
                    .opacity(isHoveringWindow ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: isHoveringWindow)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 24)
            .padding(.top, 16)
            
            Spacer()
            
            // Session Title
            SharedSessionTitleView(timerManager: timerManager)
            
            // Timer Display
            Text(timerManager.remainingTimeFormatted)
                .font(.system(size: 72, weight: .regular, design: .default))
                .monospacedDigit()
                .padding(.vertical, -4)
            
            // Progress Indicators
            SessionProgressView(timerManager: timerManager)
            
            Spacer()
            
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
                            .font(.headline)
                    }
                    .buttonStyle(PrimaryAmbientButtonStyle())
                }
                .padding(.bottom, 24)
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
        // Clean white background behavior with rounded corners, smoothly transitioning themes
        .ambientTheme(currentTheme)
        .onHover { hover in
            isHoveringWindow = hover
        }
        .onExitCommand {
            WindowManager.shared.hideMainTimer()
        }
    }
}

struct GoalProgressView: View {
    let progress: DailyGoalProgress
    var showTitle: Bool = true
    var showText: Bool = true
    var dotSize: CGFloat = 10
    var spacing: CGFloat = 12
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        VStack(spacing: 6) {
            if showTitle {
                Text(progress.title)
                    .font(.caption)
                    .foregroundColor(theme.secondaryForegroundColor)
            }
            
            ProgressDotsView(totalDots: progress.totalDots, filledDots: progress.filledDots, dotSize: dotSize, spacing: spacing)
            
            if showText {
                Text(progress.displayText)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryForegroundColor)
            }
        }
    }
}

enum DotState {
    case empty
    case half
    case full
}

struct SessionDotView: View {
    let state: DotState
    let size: CGFloat
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        ZStack {
            // Background (empty state)
            Circle()
                .fill(theme.inactiveDotColor)
                .frame(width: size, height: size)
            
            if state == .full {
                Circle()
                    .fill(theme.activeDotColor)
                    .frame(width: size, height: size)
            } else if state == .half {
                // Left half filled
                Circle()
                    .fill(theme.activeDotColor)
                    .frame(width: size, height: size)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle().frame(width: size / 2, height: size)
                            Color.clear.frame(width: size / 2, height: size)
                        }
                    )
            }
        }
    }
}

struct SessionProgressView: View {
    var timerManager: TimerManager
    var dotSize: CGFloat = 10
    var spacing: CGFloat = 12
    
    private func dotState(for index: Int) -> DotState {
        if timerManager.phase == .work {
            if index < timerManager.currentSession - 1 { return .full }
            if index == timerManager.currentSession - 1 { 
                return timerManager.state == .idle ? .empty : .half 
            }
            return .empty
        } else {
            if index <= timerManager.currentSession - 1 { return .full }
            return .empty
        }
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            let total = max(1, timerManager.totalSessions)
            ForEach(0..<total, id: \.self) { index in
                SessionDotView(state: dotState(for: index), size: dotSize)
                    .scaleEffect(index == timerManager.currentSession - 1 ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: timerManager.currentSession)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: timerManager.phase)
            }
        }
    }
}

struct ProgressDotsView: View {
    let totalDots: Int
    let filledDots: Int
    var activeDotIndex: Int? = nil
    var dotSize: CGFloat = 10
    var spacing: CGFloat = 12
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        HStack(spacing: spacing) {
            let validTotal = max(1, totalDots)
            ForEach(0..<validTotal, id: \.self) { index in
                Circle()
                    .fill(index < filledDots ? theme.activeDotColor : theme.inactiveDotColor)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(index == activeDotIndex ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: filledDots)
            }
        }
    }
}


#Preview {
    ContentView(timerManager: TimerManager())
}
