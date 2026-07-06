import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class WindowManager {
    static let shared = WindowManager()
    
    var mainPanel: FlowPanel?
    var miniPanel: FlowPanel?
    var timerManager: TimerManager?
    
    private init() {
        UserDefaults.standard.removeObject(forKey: "alwaysOnTop")
        UserDefaults.standard.removeObject(forKey: "restorePosition")
        
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, let window = notification.object as? NSWindow else { return }
            
            if window == self.mainPanel {
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
    
    func showMainTimer() {
        if let panel = mainPanel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        
        guard let timerManager = timerManager else { return }
        
        let panel = makeHostingPanel(
            rootView: ContentView(timerManager: timerManager),
            savedXKey: "windowX",
            savedYKey: "windowY"
        )
        
        self.mainPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }
    
    func hideMainTimer() {
        mainPanel?.orderOut(nil)
    }
    
    private func makeHostingPanel<Content: View>(rootView: Content, savedXKey: String, savedYKey: String) -> FlowPanel {
        let panel = FlowPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = .intrinsicContentSize
        panel.contentViewController = hostingController
        
        let x = UserDefaults.standard.object(forKey: savedXKey) as? CGFloat
        let y = UserDefaults.standard.object(forKey: savedYKey) as? CGFloat
        if let x = x, let y = y {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }
        
        return panel
    }
    
    func showMiniTimer() {
        if let panel = miniPanel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        
        guard let timerManager = timerManager else { return }
        
        let panel = makeHostingPanel(
            rootView: CompactTimerView(timerManager: timerManager),
            savedXKey: "miniWindowX",
            savedYKey: "miniWindowY"
        )
        
        self.miniPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }
    
    func hideMiniTimer() {
        miniPanel?.orderOut(nil)
    }
    
    func focusSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let settingsWindow = NSApp.windows.first(where: { $0.title == "Settings" }) {
            settingsWindow.makeKeyAndOrderFront(nil)
        }
    }
}

class FlowPanel: NSPanel {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}
