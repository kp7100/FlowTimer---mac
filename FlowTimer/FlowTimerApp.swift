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
        WindowGroup(id: "mainWindow") {
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
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            VStack(spacing: 8) {
                Text("FlowTimer")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Settings")
                    .font(.headline)
                Text("Coming Soon")
                    .foregroundColor(.secondary)
            }
            .frame(width: 400, height: 300)
        }
    }
}
