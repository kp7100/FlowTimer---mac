import SwiftUI
import AppKit

class StatusBarManager: NSObject, NSPopoverDelegate {
    static let shared = StatusBarManager()
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var timerManager: TimerManager?
    
    private var hostingView: NSHostingView<AnyView>?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var lastAppliedWidth: CGFloat = -1.0
    
    private override init() {
        super.init()
    }
    
    func setup(timerManager: TimerManager) {
        guard statusItem == nil else { return }
        self.timerManager = timerManager
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem.button else { return }
        
        button.title = ""
        button.image = nil
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.delegate = self
        
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
            
            // Only update if the width has actually changed by a meaningful threshold
            guard abs(self.lastAppliedWidth - newWidth) > 0.5 else { return }
            
            self.lastAppliedWidth = newWidth
            
            // We MUST defer the AppKit frame mutation to the next run loop cycle.
            // If we mutate `statusItem.length` synchronously here, AppKit immediately triggers
            // `-layoutSubtreeIfNeeded` on the NSStatusBarButton and its NSHostingView subview.
            // Because this closure is fired by a SwiftUI GeometryReader *during* a SwiftUI layout pass,
            // AppKit would attempt to re-layout the NSHostingView while it is already actively being laid out,
            // causing the "NSHostingView is being laid out reentrantly" layout recursion warning.
            // Dispatching async safely breaks this synchronous feedback loop.
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.length = newWidth
            }
        }
        
        if hostingView == nil {
            let hosting = NSHostingView(rootView: AnyView(menuBarView))
            hosting.translatesAutoresizingMaskIntoConstraints = false
            hosting.layer?.backgroundColor = NSColor.clear.cgColor
            
            button.addSubview(hosting)
            
            NSLayoutConstraint.activate([
                hosting.topAnchor.constraint(equalTo: button.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                hosting.centerXAnchor.constraint(equalTo: button.centerXAnchor)
            ])
            
            self.hostingView = hosting
        } else {
            hostingView?.rootView = AnyView(menuBarView)
        }
    }
    
    func popoverDidClose(_ notification: Notification) {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        // Clear focus to prevent any SwiftUI buttons from retaining focus across appearances
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
        
        // Release the SwiftUI hierarchy from memory when not visible
        popover.contentViewController = nil
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        WindowLifecycleObserver.shared.logEvent("🔘 Menu bar button clicked (togglePopover called)")
        if popover.isShown {
            WindowLifecycleObserver.shared.logEvent("🔘 Closing popover...")
            popover.performClose(sender)
        } else {
            WindowLifecycleObserver.shared.logEvent("🔘 Opening popover...")
            if let button = statusItem.button, let timerManager = timerManager {
                // Recreate the hosting controller every time to prevent sticky SwiftUI states (like button focus/hover)
                // This mimics native NSMenu behavior which is stateless across presentations.
                // let popoverView = MenuBarPopoverView(timerManager: timerManager)
                let popoverView = TextFieldPrototypeView()
                popover.contentViewController = NSHostingController(rootView: popoverView)
                
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // Add global monitor to close popover when clicking outside
                if globalEventMonitor == nil {
                    globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                        self?.popover.performClose(nil)
                    }
                }
                
                // Add local monitor to prevent Space key from triggering the status item button while typing
                // TODO: Revisit after Main Window experiment.
                // This is a specific workaround for the Space key. A cleaner architectural fix would be to
                // have the popover enter an editing mode where the status bar button ignores keyboard activation
                // entirely, allowing the text field to fully own the keyboard via the responder chain.
                if localEventMonitor == nil {
                    localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                        // Space (49) and Arrow Keys (123-126) natively trigger menu bar navigation or button clicks,
                        // causing the popover to dismiss. If we are editing, intercept them and forward them directly.
                        if event.keyCode == 49 || (123...126).contains(event.keyCode) {
                            // Check if a text field is currently the first responder
                            if let firstResponder = self?.popover.contentViewController?.view.window?.firstResponder as? NSTextView,
                               firstResponder.isEditable {
                                // Forward the event directly to the text view (handles spacing, cursor movement, etc.)
                                firstResponder.keyDown(with: event)
                                // Swallow the event so it never reaches the NSStatusBarButton / Menu navigation
                                return nil
                            }
                        }
                        return event
                    }
                }
            }
        }
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
