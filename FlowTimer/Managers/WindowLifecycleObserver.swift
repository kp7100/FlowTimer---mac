import Cocoa
import OSLog

class WindowLifecycleObserver {
    static let shared = WindowLifecycleObserver()
    
    private let logger = Logger(subsystem: "com.flowtimer.debugging", category: "WindowLifecycle")
    private let dateFormatter: DateFormatter
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    func start() {
        let center = NotificationCenter.default
        let wsCenter = NSWorkspace.shared.notificationCenter
        
        center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.log("🔑 windowDidBecomeKey: \(self?.describe(window) ?? "Unknown")")
        }
        
        center.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.log("🔓 windowDidResignKey: \(self?.describe(window) ?? "Unknown")")
        }
        
        center.addObserver(forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.log("🌟 windowDidBecomeMain: \(self?.describe(window) ?? "Unknown")")
        }
        
        center.addObserver(forName: NSWindow.didResignMainNotification, object: nil, queue: .main) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.log("⭐ windowDidResignMain: \(self?.describe(window) ?? "Unknown")")
        }
        
        wsCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier == Bundle.main.bundleIdentifier {
                self?.log("🚀 FlowTimer DID BECOME ACTIVE")
            }
        }
        
        wsCenter.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier == Bundle.main.bundleIdentifier {
                self?.log("💤 FlowTimer DID DEACTIVATE")
            }
        }
        
        wsCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.log("🌌 SPACE DID CHANGE")
        }
        
        log("✅ WindowLifecycleObserver Started")
    }
    
    func logEvent(_ message: String) {
        log(message)
    }
    
    private func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let fullMessage = "[\(timestamp)] \(message)"
        print(fullMessage)
        logger.debug("\(fullMessage, privacy: .public)")
    }
    
    private func describe(_ window: NSWindow) -> String {
        let title = window.title.isEmpty ? "<No Title>" : "\"\(window.title)\""
        let typeName = String(describing: type(of: window))
        
        var notes = ""
        if typeName.contains("Popover") {
            notes = " (Likely the Popover)"
        } else if window is NSPanel {
            notes = " (NSPanel - possibly Mini Timer or Main Window)"
        }
        
        var behaviorFlags: [String] = []
        if window.collectionBehavior.contains(.canJoinAllSpaces) { behaviorFlags.append("canJoinAllSpaces") }
        if window.collectionBehavior.contains(.fullScreenAuxiliary) { behaviorFlags.append("fullScreenAuxiliary") }
        if window.collectionBehavior.contains(.moveToActiveSpace) { behaviorFlags.append("moveToActiveSpace") }
        if window.collectionBehavior.contains(.transient) { behaviorFlags.append("transient") }
        if window.collectionBehavior.contains(.stationary) { behaviorFlags.append("stationary") }
        let behaviorString = behaviorFlags.isEmpty ? "None" : behaviorFlags.joined(separator: ", ")
        
        return "[\(typeName)] \(title)\(notes) [Level: \(window.level.rawValue)] [Behavior: \(behaviorString) (\(window.collectionBehavior.rawValue))]"
    }
}
