//
//  FlowTimerApp.swift
//  FlowTimer
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let timerManager = TimerManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        WindowManager.shared.timerManager = timerManager
        
        // Spawn the main timer deterministically on launch
        DispatchQueue.main.async {
            WindowManager.shared.showMainTimer()
        }
    }
}

@main
struct FlowTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        Window("Settings", id: "settingsWindow") {
            TabView {
                SettingsView(settingsManager: .shared, timerManager: appDelegate.timerManager)
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
            MenuBarPopoverView(timerManager: appDelegate.timerManager)
        } label: {
            Text("\(appDelegate.timerManager.menuBarTitle)   [\(appDelegate.timerManager.remainingTimeFormatted)]")
                .monospacedDigit()
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenMainWindow"))) { _ in
                    WindowManager.shared.showMainTimer()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
