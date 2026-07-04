import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class WindowManager {
    static let shared = WindowManager()
    
    var alwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
            updateWindowLevel()
        }
    }
    
    var restorePosition: Bool {
        didSet {
            UserDefaults.standard.set(restorePosition, forKey: "restorePosition")
        }
    }
    
    weak var mainWindow: NSWindow? {
        didSet {
            setupWindow()
        }
    }
    
    private init() {
        self.alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        self.restorePosition = UserDefaults.standard.object(forKey: "restorePosition") as? Bool ?? true
        
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, let window = notification.object as? NSWindow, window == self.mainWindow else { return }
            if self.restorePosition {
                let frame = window.frame
                UserDefaults.standard.set(frame.origin.x, forKey: "windowX")
                UserDefaults.standard.set(frame.origin.y, forKey: "windowY")
            }
        }
    }
    
    private func setupWindow() {
        guard let window = mainWindow else { return }
        
        updateWindowLevel()
        
        if restorePosition {
            let x = UserDefaults.standard.object(forKey: "windowX") as? CGFloat
            let y = UserDefaults.standard.object(forKey: "windowY") as? CGFloat
            if let x = x, let y = y {
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }
    
    private func updateWindowLevel() {
        mainWindow?.level = alwaysOnTop ? .floating : .normal
    }
    
    func focusMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }
}
