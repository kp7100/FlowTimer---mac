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
    
    weak var miniWindow: NSWindow? {
        didSet {
            setupMiniWindow()
        }
    }
    
    private init() {
        UserDefaults.standard.removeObject(forKey: "alwaysOnTop")
        UserDefaults.standard.removeObject(forKey: "restorePosition")
        
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, let window = notification.object as? NSWindow else { return }
            
            if window == self.mainWindow {
                let frame = window.frame
                UserDefaults.standard.set(frame.origin.x, forKey: "windowX")
                UserDefaults.standard.set(frame.origin.y, forKey: "windowY")
            } else if window == self.miniWindow {
                let frame = window.frame
                UserDefaults.standard.set(frame.origin.x, forKey: "miniWindowX")
                UserDefaults.standard.set(frame.origin.y, forKey: "miniWindowY")
            }
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
    
    private func setupMiniWindow() {
        guard let window = miniWindow else { return }
        
        window.level = .floating
        
        let x = UserDefaults.standard.object(forKey: "miniWindowX") as? CGFloat
        let y = UserDefaults.standard.object(forKey: "miniWindowY") as? CGFloat
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
