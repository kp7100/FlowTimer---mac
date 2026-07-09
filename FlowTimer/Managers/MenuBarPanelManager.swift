import SwiftUI
import AppKit

class MenuBarPanel: NSPanel {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        // We MUST NOT use hidesOnDeactivate = true in an LSUIElement app unless we explicitly NSApp.activate()
        // Otherwise, WindowServer will permanently suppress the panel from being drawn.
        self.hidesOnDeactivate = false
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}

enum PanelState {
    case closed
    case opening
    case open
    case closing
}

class MenuBarPanelManager: NSObject {
    static let shared = MenuBarPanelManager()
    
    private var statusItem: NSStatusItem!
    private var panel: MenuBarPanel!
    private var timerManager: TimerManager?
    
    private var lastAppliedWidth: CGFloat = -1.0
    
    private var panelState: PanelState = .closed
    private var currentAnimationID: UUID?
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }
    
    func setup(timerManager: TimerManager) {
        guard statusItem == nil else { return }
        self.timerManager = timerManager
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem.button else { return }
        
        button.title = ""
        button.image = nil
        button.action = #selector(togglePanel(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        panel = MenuBarPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        updateHostingView()
    }
    
    deinit {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
    
    private func updateHostingView() {
        guard let button = statusItem.button, let timerManager = timerManager else { return }
        
        let menuBarView = MenuBarStatusView(timerManager: timerManager) { [weak self] newWidth in
            guard let self = self else { return }
            guard abs(self.lastAppliedWidth - newWidth) > 0.5 else { return }
            
            self.lastAppliedWidth = newWidth
            
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.length = newWidth
            }
        }
        
        // Setup status item view
        let hosting = NSHostingView(rootView: AnyView(menuBarView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hosting)
        
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: button.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            hosting.centerXAnchor.constraint(equalTo: button.centerXAnchor)
        ])
    }
    
    @objc private func panelDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == panel else { return }
        
        // Hide panel when it loses key status (e.g. clicking outside)
        if panelState == .open || panelState == .opening {
            hidePanel()
        }
    }
    
    @objc func togglePanel(_ sender: AnyObject?) {
        switch panelState {
        case .open, .opening:
            hidePanel()
        case .closed, .closing:
            showPanel()
        }
    }
    
    func showPanel() {
        guard let button = statusItem.button, let timerManager = timerManager else { return }
        
        panelState = .opening
        let animationID = UUID()
        currentAnimationID = animationID
        
        let panelView = MenuBarPanelView(timerManager: timerManager)
        let hostingController = NSHostingController(rootView: panelView)
        hostingController.sizingOptions = .intrinsicContentSize
        
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hostingController
        
        let targetSize = hostingController.sizeThatFits(in: NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
        var currentFrame = panel.frame
        currentFrame.size = targetSize
        panel.setFrame(currentFrame, display: false)
        
        if let buttonWindow = button.window, let screen = buttonWindow.screen {
            let buttonFrame = buttonWindow.convertToScreen(button.frame)
            let panelWidth = targetSize.width
            var x = buttonFrame.midX - (panelWidth / 2)
            
            let screenRect = screen.visibleFrame
            if x < screenRect.minX { x = screenRect.minX + 8 }
            if x + panelWidth > screenRect.maxX { x = screenRect.maxX - panelWidth - 8 }
            
            panel.setFrameTopLeftPoint(NSPoint(x: x, y: buttonFrame.minY - 5))
        } else {
            assertionFailure("Failed to resolve status item position. Falling back to main screen.")
            if let screen = NSScreen.main {
                let x = screen.visibleFrame.maxX - targetSize.width - 20
                let y = screen.visibleFrame.maxY - 20
                panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
            }
        }
        
        panel.alphaValue = 0.0
        panel.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1.0
        }, completionHandler: { [weak self] in
            guard let self = self, self.currentAnimationID == animationID else { return }
            self.panelState = .open
        })
    }
    
    func hidePanel() {
        panelState = .closing
        let animationID = UUID()
        currentAnimationID = animationID
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self, self.currentAnimationID == animationID else { return }
            
            self.panel.orderOut(nil)
            self.panel.contentViewController = nil
            self.panelState = .closed
        })
    }
}

struct MenuBarStatusView: View {
    var timerManager: TimerManager
    var onWidthChange: ((CGFloat) -> Void)?
    
    @State private var isDarkMode: Bool = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    
    var body: some View {
        let theme = AmbientTheme.current(for: timerManager.phase, isDarkMode: isDarkMode)
        
        HStack(spacing: 4) {
            if !timerManager.menuBarTitle.isEmpty {
                Text(timerManager.menuBarTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            
            Text(timerManager.remainingTimeFormatted)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(theme.menuBarPillBackground)
                        .animation(.easeInOut(duration: theme.animationDuration), value: theme.menuBarPillBackground)
                )
                .foregroundStyle(theme.menuBarPillForeground)
        }
        .fixedSize()
        .background(
            GeometryReader { geo in
                Color.clear.onChange(of: geo.size.width) { _, newWidth in
                    onWidthChange?(newWidth)
                }
                .onAppear {
                    onWidthChange?(geo.size.width)
                }
            }
        )
        .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))) { _ in
            isDarkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        }
    }
}
