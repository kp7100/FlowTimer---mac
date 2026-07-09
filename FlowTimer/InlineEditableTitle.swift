import SwiftUI
import AppKit

struct InlineEditableTitle: View {
    @Binding var title: String
    
    // Customization properties
    var fontSize: CGFloat = 26
    var fontWeight: Font.Weight = .medium
    var alignment: TextAlignment = .center
    var frameAlignment: Alignment = .center
    
    @State private var isHovering = false
    @State private var isEditing = false
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        NativeInlineTextField(
            text: $title,
            fontSize: fontSize,
            fontWeight: fontWeight,
            alignment: alignment,
            foregroundColor: theme.foregroundColor,
            secondaryForegroundColor: theme.secondaryForegroundColor,
            isEditing: $isEditing
        )
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .padding(.vertical, 4)
        .padding(.horizontal, 4) // Reduced from 12 so it doesn't push the leading edge too much in the mini timer
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.foregroundColor.opacity(isHovering && !isEditing ? 0.06 : 0))
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hover
            }
        }
    }
}

struct NativeInlineTextField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var fontWeight: Font.Weight
    var alignment: TextAlignment
    var foregroundColor: Color
    var secondaryForegroundColor: Color
    @Binding var isEditing: Bool
    
    func makeNSView(context: Context) -> ClickToEditTextField {
        let textField = ClickToEditTextField()
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.isEditable = false // Initially false to look like a label
        textField.isSelectable = false
        textField.delegate = context.coordinator
        
        let weight = nsFontWeight(from: fontWeight)
        textField.font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        
        switch alignment {
        case .leading: textField.alignment = .left
        case .center: textField.alignment = .center
        case .trailing: textField.alignment = .right
        }
        
        textField.usesSingleLineMode = true
        textField.cell?.isScrollable = true
        textField.cell?.wraps = false
        textField.maximumNumberOfLines = 1
        textField.lineBreakMode = .byTruncatingTail
        
        // CRITICAL FIX: Allow SwiftUI to squish the text field so native truncation can kick in
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        textField.onBeginEditing = {
            context.coordinator.draftText = textField.stringValue
            DispatchQueue.main.async {
                self.isEditing = true
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: ClickToEditTextField, context: Context) {
        if !isEditing {
            nsView.stringValue = text.isEmpty ? "What's your focus?" : text
            nsView.textColor = text.isEmpty ? NSColor(secondaryForegroundColor) : NSColor(foregroundColor)
            nsView.lineBreakMode = .byTruncatingTail
        } else {
            nsView.lineBreakMode = .byClipping // Allows native scrolling without ellipsis while typing
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func nsFontWeight(from weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeInlineTextField
        var draftText = ""
        
        init(_ parent: NativeInlineTextField) {
            self.parent = parent
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                textField.textColor = NSColor(parent.foregroundColor)
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                textField.isEditable = false
                textField.isSelectable = false
                
                let newText = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                parent.text = newText
                
                DispatchQueue.main.async {
                    self.parent.isEditing = false
                }
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let textField = control as? NSTextField {
                    textField.stringValue = draftText
                    // Ending editing will trigger controlTextDidEndEditing where state is reset
                    textField.window?.makeFirstResponder(nil)
                }
                return true
            }
            return false
        }
    }
}

class ClickToEditTextField: NSTextField {
    var onBeginEditing: (() -> Void)?
    
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
}
