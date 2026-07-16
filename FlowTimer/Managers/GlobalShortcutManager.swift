import Foundation
import Cocoa
import Carbon

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    
    private let defaultsKey = "FlowTimerShortcuts"
    private var eventHandler: EventHandlerRef?
    private var registeredHotKeys: [ShortcutAction: EventHotKeyRef] = [:]
    
    var definitions: [ShortcutDefinition] = [] {
        didSet { saveDefinitions() }
    }
    
    var onShortcutTriggered: ((ShortcutAction) -> Void)?
    
    private init() {
        loadDefinitions()
    }
    
    func start() {
        registerAll()
    }
    
    private func loadDefinitions() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([ShortcutDefinition].self, from: data) {
            
            // Merge in any new default shortcuts that aren't in the saved payload (e.g. from app updates)
            var merged = saved
            for defaultDef in ShortcutDefinition.defaultShortcuts {
                if !merged.contains(where: { $0.action == defaultDef.action }) {
                    merged.append(defaultDef)
                }
            }
            self.definitions = merged
            
        } else {
            self.definitions = ShortcutDefinition.defaultShortcuts
        }
    }
    
    private func saveDefinitions() {
        if let data = try? JSONEncoder().encode(definitions) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    func registerAll() {
        unregisterAll()
        installEventHandler()
        
        for def in definitions where def.enabled {
            register(definition: def)
        }
    }
    
    func unregisterAll() {
        for hotKey in registeredHotKeys.values {
            UnregisterEventHotKey(hotKey)
        }
        registeredHotKeys.removeAll()
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    private func register(definition: ShortcutDefinition) {
        let signature = "FLTM".utf8.prefix(4).reduce(0) { ($0 << 8) | OSType($1) }
        let hotKeyID = EventHotKeyID(signature: signature, id: definition.action.rawID)
        var hotKeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            UInt32(definition.keyCode),
            definition.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        
        if status == noErr, let ref = hotKeyRef {
            registeredHotKeys[definition.action] = ref
        }
    }
    
    private func installEventHandler() {
        guard eventHandler == nil else { return }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        
        let handler: EventHandlerUPP = { nextHandler, theEvent, userData in
            guard let event = theEvent, let userData = userData else { return noErr }
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKey(id: hotKeyID.id)
            }
            
            return noErr
        }
        
        InstallEventHandler(GetEventDispatcherTarget(), handler, 1, &eventType, ptr, &eventHandler)
    }
    
    private func handleHotKey(id: UInt32) {
        guard let action = ShortcutAction.from(rawID: id) else { return }
        self.onShortcutTriggered?(action)
    }
}
