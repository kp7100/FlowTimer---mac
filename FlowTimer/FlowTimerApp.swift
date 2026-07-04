//
//  FlowTimerApp.swift
//  FlowTimer
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct FlowTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
        
        Window("Settings", id: "settingsWindow") {
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
    }
}
