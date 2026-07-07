import Foundation
import AppKit

class ShortcutDispatcher {
    static let shared = ShortcutDispatcher()
    
    private init() {}
    
    func start() {
        GlobalShortcutManager.shared.onShortcutTriggered = { [weak self] action in
            self?.dispatch(action: action)
        }
        GlobalShortcutManager.shared.start()
    }
    
    private func dispatch(action: ShortcutAction) {
        switch action {
        case .toggleTimer:
            WindowManager.shared.timerManager?.toggleTimer()
        case .skipPhase:
            WindowManager.shared.timerManager?.skipCurrentPhase()
        case .toggleMainWindow:
            WindowManager.shared.toggleMainTimer()
        case .toggleMiniWindow:
            WindowManager.shared.toggleMiniTimer()
        case .renameCurrentSession:
            WindowManager.shared.showRenameSessionPanel()
        }
    }
}
