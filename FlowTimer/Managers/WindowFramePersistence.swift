import AppKit

@MainActor
final class WindowFramePersistence {
    private var observers: [ObjectIdentifier: [NSObjectProtocol]] = [:]
    private var saveWorkItems: [ObjectIdentifier: DispatchWorkItem] = [:]
    
    /// Registers a window for manual frame persistence.
    /// - Parameters:
    ///   - window: The window to manage.
    ///   - persistenceKey: The UserDefaults key (e.g., "FlowTimer.MiniTimer.Frame").
    func register(window: NSWindow, persistenceKey: String) {
        // 1. Restore frame if available and valid
        var didRestore = false
        if let savedString = UserDefaults.standard.string(forKey: persistenceKey) {
            let savedFrame = NSRectFromString(savedString)
            
            // Validate against all connected screens using visibleFrame (excluding Dock/Menu bar)
            let isValid = NSScreen.screens.contains { screen in
                screen.visibleFrame.intersects(savedFrame)
            }
            
            if isValid {
                window.setFrame(savedFrame, display: false)
                didRestore = true
            }
        }
        
        // Fall back to default placement if no valid frame was found
        if !didRestore {
            window.center()
        }
        
        let windowId = ObjectIdentifier(window)
        
        // Clean up any existing observers for this window to prevent duplicates
        unregister(windowId: windowId)
        
        // 2. Observe move and resize notifications
        let moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self, weak window] _ in
            guard let window = window else { return }
            self?.scheduleSave(for: window, key: persistenceKey)
        }
        
        let resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self, weak window] _ in
            guard let window = window else { return }
            self?.scheduleSave(for: window, key: persistenceKey)
        }
        
        // Clean up automatically when the window is completely deallocated/closed
        let closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.unregister(windowId: windowId)
        }
        
        observers[windowId] = [moveObserver, resizeObserver, closeObserver]
    }
    
    private func scheduleSave(for window: NSWindow, key: String) {
        let windowId = ObjectIdentifier(window)
        
        // Cancel any pending write to debounce rapidly firing notifications
        saveWorkItems[windowId]?.cancel()
        
        let frame = window.frame
        let workItem = DispatchWorkItem {
            let frameString = NSStringFromRect(frame)
            UserDefaults.standard.set(frameString, forKey: key)
        }
        
        saveWorkItems[windowId] = workItem
        // 300ms debounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    private func unregister(windowId: ObjectIdentifier) {
        saveWorkItems[windowId]?.cancel()
        saveWorkItems.removeValue(forKey: windowId)
        
        if let tokens = observers.removeValue(forKey: windowId) {
            for token in tokens {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
}
