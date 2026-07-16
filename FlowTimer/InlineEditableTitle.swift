import SwiftUI
import AppKit

struct InlineEditableTitle: View {
    let displayTitle: String
    @Binding var customTitle: String?
    
    // Customization properties
    var fontSize: CGFloat = 26
    var fontWeight: Font.Weight = .medium
    var alignment: TextAlignment = .center
    var frameAlignment: Alignment = .center
    
    @State private var isHovering = false
    @State private var isEditing = false
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        let textBinding = Binding<String>(
            get: { customTitle ?? "" },
            set: { customTitle = $0.isEmpty ? nil : $0 }
        )
        
        let nsFontWeight: NSFont.Weight = {
            switch fontWeight {
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
        }()
        
        let nsAlignment: NSTextAlignment = {
            switch alignment {
            case .leading: return .left
            case .center: return .center
            case .trailing: return .right
            }
        }()
        
        SharedInlineTextField(
            displayTitle: displayTitle,
            text: textBinding,
            placeholder: "What's your focus?",
            placeholderColor: NSColor(theme.secondaryForegroundColor.opacity(0.5)),
            font: .systemFont(ofSize: fontSize, weight: nsFontWeight),
            textColor: NSColor(theme.foregroundColor),
            alignment: nsAlignment,
            isEditing: $isEditing,
            onCommit: { newText in
                customTitle = newText.isEmpty ? nil : newText
            }
        )
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .padding(.vertical, 4)
        .onOutsideClick(isActive: isEditing) {
            isEditing = false
        }
        .padding(.horizontal, 4) // Reduced from 12 so it doesn't push the leading edge too much in the mini timer
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.foregroundColor.opacity((isHovering || isEditing) ? 0.06 : 0))
        )
        .animation(.easeInOut(duration: 0.2), value: isHovering || isEditing)
        .onHover { hover in
            isHovering = hover
        }
    }
}


