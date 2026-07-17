import SwiftUI
import AppKit

struct SharedInlineTextField: NSViewRepresentable {
    var displayTitle: String // The text to show when NOT editing
    @Binding var text: String // The actual editable string
    var placeholder: String
    var placeholderColor: NSColor
    var font: NSFont
    var textColor: NSColor
    var alignment: NSTextAlignment
    
    @Binding var isEditing: Bool
    
    var onCommit: (String) -> Void
    
    func makeNSView(context: Context) -> ClickToEditTextField {
        let textField = ClickToEditTextField(frame: .zero)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        
        textField.font = font
        textField.textColor = textColor
        textField.alignment = alignment
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: placeholderColor,
            .font: font
        ]
        textField.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: attributes)
        
        textField.delegate = context.coordinator
        
        textField.usesSingleLineMode = true
        textField.cell?.isScrollable = true
        textField.cell?.wraps = false
        textField.maximumNumberOfLines = 1
        // Allow the text field to naturally occupy full available width
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        context.coordinator.textField = textField
        
        // This is the ONE path to begin editing.
        textField.onBeginEditing = {
            context.coordinator.draftText = textField.stringValue
            textField.stringValue = self.text
            context.coordinator.editingTextField = textField
            
            DispatchQueue.main.async {
                self.isEditing = true
            }
        }
        
        // Determine entry mode:
        if isEditing {
            // Editing Mode (used by Todo): It is created already in edit mode.
            textField.isEditable = true
            textField.isSelectable = true
            textField.lineBreakMode = .byClipping
            textField.stringValue = text
            
            // Programmatically invoke the exact same lifecycle that mouseDown uses
            DispatchQueue.main.async {
                textField.window?.makeFirstResponder(textField)
                textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
                textField.onBeginEditing?()
            }
        } else {
            // Label Mode (used by Session Title): It waits for mouseDown.
            textField.isEditable = false
            textField.isSelectable = false
            textField.lineBreakMode = .byTruncatingTail
            textField.stringValue = displayTitle
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: ClickToEditTextField, context: Context) {
        nsView.textColor = textColor
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: placeholderColor,
            .font: font
        ]
        nsView.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: attributes)
        
        if !isEditing {
            nsView.stringValue = displayTitle
            nsView.lineBreakMode = .byTruncatingTail
        } else {
            nsView.lineBreakMode = .byClipping
        }
    }
    
    static func dismantleNSView(_ nsView: ClickToEditTextField, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SharedInlineTextField
        var draftText: String = ""
        weak var editingTextField: ClickToEditTextField?
        weak var textField: ClickToEditTextField?
        
        init(_ parent: SharedInlineTextField) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(focusLost), name: NSWindow.didResignKeyNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(focusLost), name: NSApplication.didResignActiveNotification, object: nil)
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField {
                parent.text = tf.stringValue
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            endEditing(obj.object as? ClickToEditTextField)
        }
        
        @objc func focusLost(_ notification: Notification) {
            if parent.isEditing, let tf = editingTextField {
                tf.window?.makeFirstResponder(nil)
            }
        }
        
        private func endEditing(_ tf: ClickToEditTextField?) {
            guard let tf = tf else { return }
            tf.isEditable = false
            tf.isSelectable = false
            
            let newText = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async {
                self.parent.isEditing = false
            }
            parent.onCommit(newText)
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let tf = control as? ClickToEditTextField {
                    tf.stringValue = draftText
                    parent.text = draftText
                    tf.window?.makeFirstResponder(nil)
                }
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let tf = control as? ClickToEditTextField {
                    tf.window?.makeFirstResponder(nil)
                }
                return true
            }
            return false
        }
    }
}

class ClickToEditTextField: NSTextField {
    var onBeginEditing: (() -> Void)?
    
    // Tell SwiftUI's layout engine that this view has no intrinsic width constraint,
    // allowing it to eagerly accept and fill all proposed width from its parent.
    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width = NSView.noIntrinsicMetric
        return size
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        if !isEditable {
            isEditable = true
            isSelectable = true
            onBeginEditing?()
            window?.makeKeyAndOrderFront(nil)
            window?.makeFirstResponder(self)
        }
        super.mouseDown(with: event)
    }
    
    override func resignFirstResponder() -> Bool {
        self.currentEditor()?.selectedRange = NSRange(location: 0, length: 0)
        return super.resignFirstResponder()
    }
    
    override func resetCursorRects() {
        if isEditable {
            super.resetCursorRects()
        } else {
            addCursorRect(bounds, cursor: .iBeam)
        }
    }
}
