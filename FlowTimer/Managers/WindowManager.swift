import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class WindowManager {
    static let shared = WindowManager()
    
    var mainPanel: FlowPanel?
    var miniPanel: FlowPanel?
    var settingsWindow: NSWindow?
    @ObservationIgnored private var _renameSessionPanelController: RenameSessionPanelController?
    var timerManager: TimerManager?
    
    let framePersistence = WindowFramePersistence()
    
    private init() {
        UserDefaults.standard.removeObject(forKey: "alwaysOnTop")
        UserDefaults.standard.removeObject(forKey: "restorePosition")
    }
    
    func showMainTimer() {
        if let panel = mainPanel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        
        guard let timerManager = timerManager else { return }
        
        let panel = makeHostingPanel(
            rootView: ContentView(timerManager: timerManager),
            autosaveName: "FlowTimer.MainTimer.Frame"
        )
        
        self.mainPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }
    
    func hideMainTimer() {
        mainPanel?.orderOut(nil)
    }
    
    func toggleMainTimer() {
        if mainPanel?.isVisible == true {
            hideMainTimer()
        } else {
            showMainTimer()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func makeHostingPanel<Content: View>(rootView: Content, autosaveName: String) -> FlowPanel {
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
        
        framePersistence.register(window: panel, persistenceKey: autosaveName)
        
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
            autosaveName: "FlowTimer.MiniTimer.Frame"
        )
        
        self.miniPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }
    
    func hideMiniTimer() {
        miniPanel?.orderOut(nil)
    }
    
    func toggleMiniTimer() {
        if miniPanel?.isVisible == true {
            hideMiniTimer()
        } else {
            showMiniTimer()
        }
    }
    
    func showSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        guard let timerManager = timerManager else { return }
        
        let settingsView = TabView {
            SettingsView(settingsManager: .shared, timerManager: timerManager)
                .tabItem { Label("Settings", systemImage: "gear") }
            
            StatisticsView()
                .tabItem { Label("Statistics", systemImage: "chart.bar.fill") }
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 400)
        window.center()
        
        let hostingController = NSHostingController(rootView: settingsView)
        window.contentViewController = hostingController
        
        framePersistence.register(window: window, persistenceKey: "FlowTimer.Settings.Frame")
        
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
            if let t = token {
                NotificationCenter.default.removeObserver(t)
            }
        }
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideSettingsWindow() {
        settingsWindow?.orderOut(nil)
    }
    
    func toggleSettingsWindow() {
        if settingsWindow?.isVisible == true {
            hideSettingsWindow()
        } else {
            showSettingsWindow()
        }
    }
    
    private func getRenamePanelController() -> RenameSessionPanelController? {
        guard let timerManager = timerManager else { return nil }
        
        if let controller = _renameSessionPanelController {
            return controller
        }
        
        let controller = RenameSessionPanelController(timerManager: timerManager)
        _renameSessionPanelController = controller
        return controller
    }
    
    func showRenameSessionPanel() {
        getRenamePanelController()?.show()
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
