import Cocoa
import SwiftUI

class RenameSessionPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

class RenameSessionPanelController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private let panel: RenameSessionPanel
    private let textField = NSTextField()
    private let titleLabel = NSTextField(labelWithString: "Edit Session Title")
    private let timerManager: TimerManager
    
    init(timerManager: TimerManager) {
        self.timerManager = timerManager
        
        self.panel = RenameSessionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 96),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        super.init()
        
        setupPanel()
        setupUI()
    }
    
    private func setupPanel() {
        panel.title = "Rename Session"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    private func setupUI() {
        guard let contentView = panel.contentView else { return }
        
        let visualEffect = NSVisualEffectView(frame: contentView.bounds)
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.appearance = NSAppearance(named: .vibrantDark)
        visualEffect.autoresizingMask = [.width, .height]
        contentView.addSubview(visualEffect)
        
        let overlay = NSView(frame: contentView.bounds)
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        overlay.autoresizingMask = [.width, .height]
        contentView.addSubview(overlay)
        
        let closeButton = FlowCloseButton(frame: .zero)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.target = self
        closeButton.action = #selector(closePanel)
        contentView.addSubview(closeButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = NSColor(white: 1.0, alpha: 0.7)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 34, weight: .semibold)
        textField.placeholderString = ""
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.delegate = self
        textField.textColor = .white
        textField.alignment = .center
        contentView.addSubview(textField)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            closeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            closeButton.widthAnchor.constraint(equalToConstant: 14),
            closeButton.heightAnchor.constraint(equalToConstant: 14),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }
    
    func show() {
        textField.stringValue = ""
        textField.placeholderString = ""
        titleLabel.stringValue = "Edit Session Title"
        
        if let screen = NSEvent.mouseLocation.screen {
            let screenRect = screen.visibleFrame
            let panelRect = panel.frame
            let x = screenRect.origin.x + (screenRect.width - panelRect.width) / 2
            let y = screenRect.origin.y + (screenRect.height - panelRect.height) / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }
        
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textField)
    }
    
    func hide() {
        panel.orderOut(nil)
    }
    
    @objc private func closePanel() {
        hide()
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
    
    // MARK: - NSTextFieldDelegate
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            hide()
            return true
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commit()
            return true
        }
        return false
    }
    
    private func commit() {
        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            timerManager.sessionTitle = trimmed
        }
        // If empty, we just leave the original title intact.
        hide()
    }
}

extension NSPoint {
    var screen: NSScreen? {
        for screen in NSScreen.screens {
            if NSMouseInRect(self, screen.frame, false) {
                return screen
            }
        }
        return NSScreen.main
    }
}
