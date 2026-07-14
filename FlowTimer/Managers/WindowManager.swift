import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class WindowManager {
    static let shared = WindowManager()
    

    var miniPanel: FlowPanel?
    var manageTagsWindow: NSWindow?
    private var manageTagsWindowObserver: NSObjectProtocol?
    var statisticsWindow: NSWindow?
    private var statisticsWindowObserver: NSObjectProtocol?
    var customDurationsWindow: NSWindow?
    private var customDurationsWindowObserver: NSObjectProtocol?
    var timerManager: TimerManager?
    
    let framePersistence = WindowFramePersistence()
    
    private init() {
        UserDefaults.standard.removeObject(forKey: "alwaysOnTop")
        UserDefaults.standard.removeObject(forKey: "restorePosition")
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
    
    private var renamePanelController: RenameSessionPanelController?
    
    func showRenameSessionPanel() {
        if renamePanelController == nil, let timerManager = timerManager {
            renamePanelController = RenameSessionPanelController(timerManager: timerManager)
        }
        renamePanelController?.show()
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
    
    func showManageTagsWindow() {
        if let window = manageTagsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let manageTagsView = ManageTagsView()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Manage Tags"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 400)
        window.center()
        
        let hostingController = NSHostingController(rootView: manageTagsView)
        window.contentViewController = hostingController
        
        framePersistence.register(window: window, persistenceKey: "FlowTimer.ManageTags.Frame")
        
        manageTagsWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.manageTagsWindow = nil
                if let observer = self?.manageTagsWindowObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.manageTagsWindowObserver = nil
                }
            }
        }
        
        self.manageTagsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showStatisticsWindow() {
        if let window = statisticsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        guard let timerManager = timerManager else { return }
        
        let statisticsView = StatisticsView(timerManager: timerManager)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Statistics"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 500, height: 500)
        window.center()
        
        let hostingController = NSHostingController(rootView: statisticsView)
        window.contentViewController = hostingController
        
        framePersistence.register(window: window, persistenceKey: "FlowTimer.Statistics.Frame")
        
        statisticsWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.statisticsWindow = nil
                if let observer = self?.statisticsWindowObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.statisticsWindowObserver = nil
                }
            }
        }
        
        self.statisticsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showCustomDurationsWindow() {
        if let window = customDurationsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let customDurationsView = CustomDurationsView()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.center()
        
        let hostingController = NSHostingController(rootView: customDurationsView)
        window.contentViewController = hostingController
        
        framePersistence.register(window: window, persistenceKey: "FlowTimer.CustomDurations.Frame")
        
        customDurationsWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.customDurationsWindow = nil
                if let observer = self?.customDurationsWindowObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.customDurationsWindowObserver = nil
                }
            }
        }
        
        self.customDurationsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideCustomDurationsWindow() {
        customDurationsWindow?.close()
    }
    
    func hideManageTagsWindow() {
        manageTagsWindow?.close()
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
