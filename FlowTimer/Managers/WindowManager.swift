import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class WindowManager {
    static let shared = WindowManager()
    
    weak var mainWindow: NSWindow? {
        didSet {
            setupWindow()
        }
    }
    
    private init() {
        UserDefaults.standard.removeObject(forKey: "alwaysOnTop")
        UserDefaults.standard.removeObject(forKey: "restorePosition")
        
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, let window = notification.object as? NSWindow, window == self.mainWindow else { return }
            let frame = window.frame
            UserDefaults.standard.set(frame.origin.x, forKey: "windowX")
            UserDefaults.standard.set(frame.origin.y, forKey: "windowY")
        }
    }
    
    private func setupWindow() {
        guard let window = mainWindow else { return }
        
        window.level = .floating
        
        let x = UserDefaults.standard.object(forKey: "windowX") as? CGFloat
        let y = UserDefaults.standard.object(forKey: "windowY") as? CGFloat
        if let x = x, let y = y {
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    func focusMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }
    
    func focusSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let settingsWindow = NSApp.windows.first(where: { $0.title == "Settings" }) {
            settingsWindow.makeKeyAndOrderFront(nil)
        }
    }
}
