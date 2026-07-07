import Foundation
import Carbon

enum ShortcutAction: String, Codable, CaseIterable {
    case toggleTimer
    case skipPhase
    case toggleMainWindow
    case toggleMiniWindow
    case renameCurrentSession
    
    var rawID: UInt32 {
        switch self {
        case .toggleTimer: return 1
        case .skipPhase: return 2
        case .toggleMainWindow: return 3
        case .toggleMiniWindow: return 4
        case .renameCurrentSession: return 5
        }
    }
    
    static func from(rawID: UInt32) -> ShortcutAction? {
        return allCases.first { $0.rawID == rawID }
    }
}

struct ShortcutDefinition: Codable, Equatable, Identifiable {
    var id: String { action.rawValue }
    
    let action: ShortcutAction
    var keyCode: Int
    var modifiers: UInt32
    var enabled: Bool
}

extension ShortcutDefinition {
    static var defaultShortcuts: [ShortcutDefinition] {
        let globalModifiers = UInt32(cmdKey | optionKey | controlKey)
        
        return [
            // F = 3
            ShortcutDefinition(action: .toggleTimer, keyCode: 3, modifiers: globalModifiers, enabled: true),
            // S = 1
            ShortcutDefinition(action: .skipPhase, keyCode: 1, modifiers: globalModifiers, enabled: true),
            // H = 4
            ShortcutDefinition(action: .toggleMainWindow, keyCode: 4, modifiers: globalModifiers, enabled: true),
            // M = 46
            ShortcutDefinition(action: .toggleMiniWindow, keyCode: 46, modifiers: globalModifiers, enabled: true),
            // T = 17
            ShortcutDefinition(action: .renameCurrentSession, keyCode: 17, modifiers: globalModifiers, enabled: true)
        ]
    }
}
