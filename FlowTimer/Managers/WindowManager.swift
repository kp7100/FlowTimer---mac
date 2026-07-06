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
    var miniPanel: MiniTimerPanel?
    var timerManager: TimerManager?
    
    private init() {
        UserDefaults.standard.removeObject(forKey: "alwaysOnTop")
        UserDefaults.standard.removeObject(forKey: "restorePosition")
        
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, let window = notification.object as? NSWindow else { return }
            
            if window == self.mainWindow {
                let frame = window.frame
                UserDefaults.standard.set(frame.origin.x, forKey: "windowX")
                UserDefaults.standard.set(frame.origin.y, forKey: "windowY")
            } else if window == self.miniPanel {
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
    
    func showMiniTimer() {
        if let panel = miniPanel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        
        guard let timerManager = timerManager else { return }
        
        let panel = MiniTimerPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel], // Borderless to avoid title bar geometry
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let hostingController = NSHostingController(rootView: CompactTimerView(timerManager: timerManager))
        hostingController.sizingOptions = .intrinsicContentSize
        panel.contentViewController = hostingController
        
        let x = UserDefaults.standard.object(forKey: "miniWindowX") as? CGFloat
        let y = UserDefaults.standard.object(forKey: "miniWindowY") as? CGFloat
        if let x = x, let y = y {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }
        
        self.miniPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }
    
    func hideMiniTimer() {
        miniPanel?.orderOut(nil)
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

class MiniTimerPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}
