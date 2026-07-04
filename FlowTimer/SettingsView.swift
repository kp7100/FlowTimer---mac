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
                    // TESTING OPTIONS
                    Text("30 sec").tag(30)
                    // END TESTING OPTIONS
                    
                    ForEach(workOptions, id: \.self) { min in
                        Text("\(min) min").tag(min * 60)
                    }
                }
            }
            
            Section("Breaks") {
                Picker("Short Break", selection: $settingsManager.settings.shortBreakDuration) {
                    // TESTING OPTIONS
                    Text("5 sec").tag(5)
                    // END TESTING OPTIONS
                    
                    ForEach(shortBreakOptions, id: \.self) { min in
                        Text("\(min) min").tag(min * 60)
                    }
                }
                
                Picker("Long Break", selection: $settingsManager.settings.longBreakDuration) {
                    // TESTING OPTIONS
                    Text("10 sec").tag(10)
                    // END TESTING OPTIONS
                    
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
                Toggle("Start Breaks Automatically", isOn: $settingsManager.settings.autoStartBreaks)
                Toggle("Start Focus Sessions Automatically", isOn: $settingsManager.settings.autoStartWork)
            }
            
            Section("Window") {
                @Bindable var windowManager = WindowManager.shared
                Toggle("Always on Top", isOn: $windowManager.alwaysOnTop)
                Toggle("Restore Previous Window Position", isOn: $windowManager.restorePosition)
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
