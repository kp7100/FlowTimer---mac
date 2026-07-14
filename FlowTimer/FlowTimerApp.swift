//
//  FlowTimerApp.swift
//  FlowTimer
//

import SwiftUI

let useNativeStatusItem = true

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let timerManager = TimerManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        WindowManager.shared.timerManager = timerManager
        
        if useNativeStatusItem {
            MenuBarPanelManager.shared.setup(timerManager: timerManager)
        }
        
        ShortcutDispatcher.shared.start()
        

        // Spawn the mini timer on launch
        DispatchQueue.main.async {
            WindowManager.shared.showMiniTimer()
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
        MenuBarExtra(isInserted: .constant(!useNativeStatusItem)) {
            MenuBarPanelView(timerManager: appDelegate.timerManager)
        } label: {
            Text("\(appDelegate.timerManager.menuBarTitle)   [\(appDelegate.timerManager.remainingTimeFormatted)]")
                .monospacedDigit()
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenMainWindow"))) { _ in
                    WindowManager.shared.showMiniTimer()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
