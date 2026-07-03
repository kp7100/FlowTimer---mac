//
//  FlowTimerApp.swift
//  FlowTimer
//

import SwiftUI

@main
struct FlowTimerApp: App {
    @State private var timerManager = TimerManager()
    
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
