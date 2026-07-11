import SwiftUI

struct SettingsView: View {
    @Bindable var settingsManager: SettingsManager
    var timerManager: TimerManager
    
    let workOptions = [15, 20, 25, 30, 45, 50, 60, 90]
    let shortBreakOptions = [5, 10]
    let longBreakOptions = [15, 20, 30]
    let sessionOptions = Array(2...10)
    @State private var showingManageTags = false
    
    var body: some View {
        ScrollView {
            Form {
            Section("Daily Goal") {
                Toggle("Enable Daily Goals", isOn: $settingsManager.settings.goalsEnabled)
                
                if settingsManager.settings.goalsEnabled {
                    Picker("Measure Progress By", selection: $settingsManager.settings.goalType) {
                        Text("Focus Time").tag(DailyGoalType.focusTime)
                        Text("Completed Sessions").tag(DailyGoalType.sessions)
                    }
                    .pickerStyle(.radioGroup)
                    
                    if settingsManager.settings.goalType == .focusTime {
                        Picker("Goal", selection: $settingsManager.settings.goalFocusTime) {
                        Text("30 min").tag(TimeInterval(30 * 60))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("2 hours").tag(TimeInterval(2 * 3600))
                        Text("3 hours").tag(TimeInterval(3 * 3600))
                        Text("4 hours").tag(TimeInterval(4 * 3600))
                        Text("5 hours").tag(TimeInterval(5 * 3600))
                        Text("6 hours").tag(TimeInterval(6 * 3600))
                    }
                } else {
                    Picker("Goal", selection: $settingsManager.settings.goalSessions) {
                        Text("2 Sessions").tag(2)
                        Text("4 Sessions").tag(4)
                        Text("6 Sessions").tag(6)
                        Text("8 Sessions").tag(8)
                        Text("10 Sessions").tag(10)
                    }
                }
                }
            }
            
            Section("Tags") {
                @Bindable var tagManager = TagManager.shared
                Picker("Selected Tag", selection: $settingsManager.settings.selectedTagId) {
                    Text("None").tag(UUID?.none)
                    Divider()
                    ForEach(tagManager.tags) { tag in
                        Text(tag.name).tag(Optional(tag.id))
                    }
                }
                
                Button("Manage Tags...") {
                    showingManageTags = true
                }
            }
            
            Section("Focus") {
                Picker("Work Duration", selection: $settingsManager.settings.workDuration) {
#if DEBUG
                    Text("30 sec (Test)").tag(30)
#endif
                    ForEach(workOptions, id: \.self) { min in
                        Text("\(min) min").tag(min * 60)
                    }
                }
            }
            
            Section("Breaks") {
                Picker("Short Break", selection: $settingsManager.settings.shortBreakDuration) {
#if DEBUG
                    Text("5 sec (Test)").tag(5)
#endif
                    ForEach(shortBreakOptions, id: \.self) { min in
                        Text("\(min) min").tag(min * 60)
                    }
                }
                
                Picker("Long Break", selection: $settingsManager.settings.longBreakDuration) {
#if DEBUG
                    Text("10 sec (Test)").tag(10)
#endif
                    ForEach(longBreakOptions, id: \.self) { min in
                        Text("\(min) min").tag(min * 60)
                    }
                }
            }
            
            Section("Cycle") {
                Picker("Sessions", selection: $settingsManager.settings.sessionsPerCycle) {
                    ForEach(sessionOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
            }
            
            Section("Automation") {
                Toggle("Launch at Login", isOn: $settingsManager.settings.launchAtLogin)
                Picker("Flow Extension Limit", selection: $settingsManager.settings.flowExtensionLimit) {
                    Text("Unlimited").tag(Int?.none)
                    Text("15 min").tag(Optional(15))
                    Text("30 min").tag(Optional(30))
                    Text("45 min").tag(Optional(45))
                    Text("60 min").tag(Optional(60))
                }
                Toggle("Start Focus Sessions Automatically", isOn: $settingsManager.settings.autoStartWork)
            }
            }
            .padding()
        }
        .sheet(isPresented: $showingManageTags) {
            ManageTagsView()
        }
        .onChange(of: settingsManager.settings) { _, _ in
            timerManager.settingsDidChange()
        }
        .onAppear {
#if !DEBUG
            if !workOptions.contains(where: { $0 * 60 == settingsManager.settings.workDuration }) {
                settingsManager.settings.workDuration = 25 * 60
            }
            if !shortBreakOptions.contains(where: { $0 * 60 == settingsManager.settings.shortBreakDuration }) {
                settingsManager.settings.shortBreakDuration = 5 * 60
            }
            if !longBreakOptions.contains(where: { $0 * 60 == settingsManager.settings.longBreakDuration }) {
                settingsManager.settings.longBreakDuration = 15 * 60
            }
#endif
        }
    }
}
