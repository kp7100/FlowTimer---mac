import SwiftUI

struct MenuBarPanelView: View {
    @Bindable var timerManager: TimerManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showingCustomGoalSheet = false
    
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
                    TagSelectorMenu(selectedTagId: Binding(
                        get: { SettingsManager.shared.settings.selectedTagId },
                        set: { SettingsManager.shared.settings.selectedTagId = $0 }
                    ))
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
                .foregroundColor(currentTheme.timerTextColor)
                .padding(.vertical, -4)
            
            // Session Progress
            SessionProgressView(timerManager: timerManager, dotSize: 10, spacing: 12)
                .padding(.bottom, 12)
            
            if timerManager.phase == .flowExtension {
                Button(action: {
                    withAnimation {
                        timerManager.takeBreak()
                    }
                }) {
                    Text("Take Break")
                        .font(.subheadline)
                }
                .buttonStyle(PrimaryAmbientButtonStyle())
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
            
            if SettingsManager.shared.settings.showTodaysFocus {
                TodaysFocusView(timerManager: timerManager)
            }
            
            Divider()
                .overlay(timerManager.phase == .flowExtension ? AmbientTheme.flowColor(isDarkMode: colorScheme == .dark).opacity(0.08) : Color.clear)
                .padding(.horizontal, 16)
            
            // Secondary Actions
            VStack(spacing: 4) {
                let isMiniTimerVisible = WindowManager.shared.miniPanel?.isVisible == true
                PopoverMenuItem(title: isMiniTimerVisible ? "Hide Mini Timer" : "Show Mini Timer") {
                    WindowManager.shared.toggleMiniTimer()
                    dismiss()
                }
                
                PopoverMenuItem(title: "Statistics") {
                    dismiss()
                    Task { @MainActor in
                        await Task.yield()
                        WindowManager.shared.showStatisticsWindow()
                    }
                }
                
                SettingsMenuView(dismiss: dismiss, showingCustomGoalSheet: $showingCustomGoalSheet)
                
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
        .flowModeTransition(timerManager: timerManager, isDarkMode: colorScheme == .dark)
        .sheet(isPresented: $showingCustomGoalSheet) {
            CustomDailyGoalSheet(initialDuration: SettingsManager.shared.settings.goalFocusTime)
        }
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

struct SettingsMenuView: View {
    let dismiss: DismissAction
    @Binding var showingCustomGoalSheet: Bool
    @State private var isHovered = false
    @Environment(\.ambientTheme) var theme
    
    private var settings: TimerSettings { SettingsManager.shared.settings }
    
    var body: some View {
        Menu {
            Menu("Work Duration") {
                let workPresets = [15, 20, 25, 30, 45, 60]
                let currentWork = settings.workDuration / 60
                let isWorkCustom = !workPresets.contains(currentWork)
                
                ForEach(workPresets, id: \.self) { min in
                    Toggle("\(min) min", isOn: Binding(
                        get: { settings.workDuration == min * 60 },
                        set: { if $0 { SettingsManager.shared.settings.workDuration = min * 60 } }
                    ))
                }
                if isWorkCustom {
                    Divider()
                    Toggle("\(currentWork) min", isOn: Binding(
                        get: { settings.workDuration == currentWork * 60 },
                        set: { if $0 { SettingsManager.shared.settings.workDuration = currentWork * 60 } }
                    ))
                }
                
                Divider()
                
                Button("Custom") {
                    WindowManager.shared.showCustomDurationsWindow()
                    dismiss()
                }
            }
            
            Menu("Break Duration") {
                Menu("Short Break") {
                    let shortPresets = [3, 5, 10, 15]
                    let currentShort = settings.shortBreakDuration / 60
                    let isShortCustom = !shortPresets.contains(currentShort)
                    
                    ForEach(shortPresets, id: \.self) { min in
                        Toggle("\(min) min", isOn: Binding(
                            get: { settings.shortBreakDuration == min * 60 },
                            set: { if $0 { SettingsManager.shared.settings.shortBreakDuration = min * 60 } }
                        ))
                    }
                    if isShortCustom {
                        Divider()
                        Toggle("\(currentShort) min", isOn: Binding(
                            get: { settings.shortBreakDuration == currentShort * 60 },
                            set: { if $0 { SettingsManager.shared.settings.shortBreakDuration = currentShort * 60 } }
                        ))
                    }
                    
                    Divider()
                    
                    Button("Custom") {
                        WindowManager.shared.showCustomDurationsWindow()
                        dismiss()
                    }
                }
                
                Menu("Long Break") {
                    let longPresets = [15, 20, 30, 45]
                    let currentLong = settings.longBreakDuration / 60
                    let isLongCustom = !longPresets.contains(currentLong)
                    
                    ForEach(longPresets, id: \.self) { min in
                        Toggle("\(min) min", isOn: Binding(
                            get: { settings.longBreakDuration == min * 60 },
                            set: { if $0 { SettingsManager.shared.settings.longBreakDuration = min * 60 } }
                        ))
                    }
                    if isLongCustom {
                        Divider()
                        Toggle("\(currentLong) min", isOn: Binding(
                            get: { settings.longBreakDuration == currentLong * 60 },
                            set: { if $0 { SettingsManager.shared.settings.longBreakDuration = currentLong * 60 } }
                        ))
                    }
                    
                    Divider()
                    
                    Button("Custom") {
                        WindowManager.shared.showCustomDurationsWindow()
                        dismiss()
                    }
                }
            }
            
            Divider()
            
            Picker("Cycle", selection: Binding(
                get: { SettingsManager.shared.settings.sessionsPerCycle },
                set: { SettingsManager.shared.settings.sessionsPerCycle = $0 }
            )) {
                ForEach(1...10, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.menu)
            
            Menu("Flow Extension Limit") {
                let flowPresets = [5, 10, 15, 20, 30]
                let currentFlow = (settings.flowExtensionLimit ?? (15 * 60)) / 60
                let isFlowCustom = settings.flowExtensionLimit != nil && !flowPresets.contains(currentFlow)
                
                Toggle("No Limit", isOn: Binding(
                    get: { settings.flowExtensionLimit == nil },
                    set: { if $0 { SettingsManager.shared.settings.flowExtensionLimit = nil } }
                ))
                
                Divider()
                
                ForEach(flowPresets, id: \.self) { min in
                    Toggle("\(min) min", isOn: Binding(
                        get: { settings.flowExtensionLimit == min * 60 },
                        set: { if $0 { SettingsManager.shared.settings.flowExtensionLimit = min * 60 } }
                    ))
                }
                
                if isFlowCustom {
                    Divider()
                    Toggle("\(currentFlow) min", isOn: Binding(
                        get: { settings.flowExtensionLimit == currentFlow * 60 },
                        set: { if $0 { SettingsManager.shared.settings.flowExtensionLimit = currentFlow * 60 } }
                    ))
                }
                
                Divider()
                
                Button("Custom") {
                    WindowManager.shared.showCustomDurationsWindow()
                    dismiss()
                }
            }
            
            Divider()
            
            Menu("Daily Goal") {
                let presets: [TimeInterval] = [30*60, 3600, 2*3600, 3*3600, 4*3600, 6*3600]
                let currentGoal = settings.goalFocusTime
                let isCustom = settings.goalsEnabled && !presets.contains(currentGoal)
                
                Toggle("Off", isOn: Binding(
                    get: { !settings.goalsEnabled },
                    set: { if $0 { SettingsManager.shared.settings.goalsEnabled = false } }
                ))
                
                Divider()
                
                ForEach(presets, id: \.self) { preset in
                    let name = preset == 30*60 ? "30 min" :
                               preset == 3600 ? "1 hour" :
                               "\(Int(preset / 3600)) hours"
                    Toggle(name, isOn: Binding(
                        get: { settings.goalsEnabled && settings.goalFocusTime == preset },
                        set: { if $0 {
                            SettingsManager.shared.settings.goalsEnabled = true
                            SettingsManager.shared.settings.goalFocusTime = preset
                        }}
                    ))
                }
                
                if isCustom {
                    Divider()
                    Toggle(TimeFormatter.formatForStats(seconds: currentGoal), isOn: Binding(
                        get: { settings.goalsEnabled && settings.goalFocusTime == currentGoal },
                        set: { if $0 {
                            SettingsManager.shared.settings.goalsEnabled = true
                            SettingsManager.shared.settings.goalFocusTime = currentGoal
                        }}
                    ))
                }
                
                Divider()
                
                Button("Custom") {
                    showingCustomGoalSheet = true
                }
            }
            
            Menu("Tags") {
                Toggle("No Tag", isOn: Binding(
                    get: { settings.selectedTagId == nil },
                    set: { if $0 { SettingsManager.shared.settings.selectedTagId = nil } }
                ))
                
                Divider()
                
                ForEach(TagManager.shared.tags) { tag in
                    Toggle(tag.name, isOn: Binding(
                        get: { settings.selectedTagId == tag.id },
                        set: { if $0 { SettingsManager.shared.settings.selectedTagId = tag.id } }
                    ))
                }
                
                Divider()
                
                Button("Manage Tags...") {
                    dismiss()
                    Task { @MainActor in
                        await Task.yield()
                        WindowManager.shared.showManageTagsWindow()
                    }
                }
            }
            
            Divider()
            
            Toggle("Start Focus Sessions Automatically", isOn: Binding(
                get: { SettingsManager.shared.settings.autoStartWork },
                set: { SettingsManager.shared.settings.autoStartWork = $0 }
            ))
            
            Toggle("Show Today's Focus", isOn: Binding(
                get: { SettingsManager.shared.settings.showTodaysFocus },
                set: { SettingsManager.shared.settings.showTodaysFocus = $0 }
            ))
            
            Picker("Reset Today's Focus at", selection: Binding(
                get: { SettingsManager.shared.settings.focusTaskResetHour },
                set: { SettingsManager.shared.settings.focusTaskResetHour = $0 }
            )) {
                Text("Midnight").tag(0)
                Text("1 AM").tag(1)
                Text("2 AM").tag(2)
                Text("3 AM").tag(3)
                Text("4 AM").tag(4)
            }
            .help("Tasks carry over past midnight until this time.")
            
            Toggle("Launch at Login", isOn: Binding(
                get: { SettingsManager.shared.settings.launchAtLogin },
                set: { SettingsManager.shared.settings.launchAtLogin = $0 }
            ))
        } label: {
            HStack {
                Text("Settings")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.6)
            }
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

struct CustomDailyGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    let initialDuration: TimeInterval
    
    @State private var hours: Int
    @State private var minutes: Int
    
    init(initialDuration: TimeInterval) {
        self.initialDuration = initialDuration
        let totalSeconds = Int(initialDuration)
        _hours = State(initialValue: totalSeconds / 3600)
        _minutes = State(initialValue: (totalSeconds % 3600) / 60)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Daily Goal")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Hours")
                        .font(.caption)
                    Stepper(value: $hours, in: 0...24) {
                        Text("\(hours)")
                            .frame(width: 30, alignment: .trailing)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Minutes")
                        .font(.caption)
                    Stepper(value: $minutes, in: 0...59, step: 5) {
                        Text("\(minutes)")
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    let totalSeconds = (hours * 3600) + (minutes * 60)
                    if totalSeconds > 0 {
                        SettingsManager.shared.settings.goalsEnabled = true
                        SettingsManager.shared.settings.goalFocusTime = TimeInterval(totalSeconds)
                    } else {
                        SettingsManager.shared.settings.goalsEnabled = false
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 250)
    }
}
