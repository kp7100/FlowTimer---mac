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
            HStack(spacing: 6) {
                Text(timerManager.menuBarTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text("[\(timerManager.remainingTimeFormatted)]")
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            Text("Settings Placeholder")
                .frame(width: 400, height: 300)
        }
    }
}
