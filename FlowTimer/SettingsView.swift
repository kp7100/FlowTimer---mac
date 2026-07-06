import SwiftUI

struct SettingsView: View {
    @Bindable var settingsManager: SettingsManager
    var timerManager: TimerManager
    
    let workOptions = [15, 20, 25, 30, 45, 50, 60, 90]
    let shortBreakOptions = [5, 10]
    let longBreakOptions = [15, 20, 30]
    let sessionOptions = [2, 3, 4, 5]
    @State private var showingManageTags = false
    
    var body: some View {
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
                    ForEach(workOptions, id: \.self) { min in
                        Text("\(min) min").tag(min * 60)
                    }
                }
            }
            
            Section("Breaks") {
                Picker("Short Break", selection: $settingsManager.settings.shortBreakDuration) {
                    ForEach(shortBreakOptions, id: \.self) { min in
                        Text("\(min) min").tag(min * 60)
                    }
                }
                
                Picker("Long Break", selection: $settingsManager.settings.longBreakDuration) {
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
                Toggle("Start Breaks Automatically", isOn: $settingsManager.settings.autoStartBreaks)
                Toggle("Start Focus Sessions Automatically", isOn: $settingsManager.settings.autoStartWork)
            }
        }
        .padding()
        .frame(width: 400, height: 580)
        .sheet(isPresented: $showingManageTags) {
            ManageTagsView()
        }
        .onChange(of: settingsManager.settings) { _, _ in
            timerManager.settingsDidChange()
        }
    }
}
