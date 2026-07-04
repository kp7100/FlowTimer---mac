//
//  FlowTimerApp.swift
//  FlowTimer
//

import SwiftUI

@main
struct FlowTimerApp: App {
    @State private var timerManager = TimerManager()
    @Environment(\.openWindow) private var openWindow
    
    init() {
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        Window("FlowTimer", id: "mainWindow") {
            ContentView(timerManager: timerManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        MenuBarExtra {
            MenuBarPopoverView(timerManager: timerManager)
        } label: {
            Text("\(timerManager.menuBarTitle)   [\(timerManager.remainingTimeFormatted)]")
                .monospacedDigit()
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenMainWindow"))) { _ in
                    openWindow(id: "mainWindow")
                    WindowManager.shared.focusMainWindow()
                }
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            TabView {
                SettingsView(settingsManager: .shared, timerManager: timerManager)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                
                StatisticsView()
                    .tabItem {
                        Label("Statistics", systemImage: "chart.bar.fill")
                    }
            }
        }
    }
}
