import SwiftUI
import AppKit

extension NSNotification.Name {
    static let sessionTitleCompleted = NSNotification.Name("SessionTitleCompleted")
}

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
    
    // Animation state
    @State private var completedTitle: String? = nil
    @State private var strikeProgress: CGFloat = 0
    @State private var completedOpacity: Double = 1.0
    @State private var newTitleOpacity: Double = 1.0
    
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
        
        ZStack(alignment: frameAlignment) {
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
                    isHovering = false
                }
            )
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding(.vertical, 4)
            .onOutsideClick(isActive: isEditing) {
                isEditing = false
            }
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.foregroundColor.opacity((isHovering || isEditing) ? 0.06 : 0))
            )
            .animation(.easeInOut(duration: 0.2), value: isHovering || isEditing)
            .onHover { hover in
                isHovering = hover
            }
            .opacity(newTitleOpacity)
            
            if let title = completedTitle {
                Text(title)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundColor(Color(theme.foregroundColor))
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color(theme.foregroundColor).opacity(0.75))
                                .frame(width: geo.size.width * strikeProgress, height: 3)
                                .offset(y: geo.size.height / 2)
                        }
                    }
                    .opacity(completedOpacity)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionTitleCompleted)) { notification in
            if let title = notification.object as? String {
                completedTitle = title
                strikeProgress = 0
                completedOpacity = 1.0
                newTitleOpacity = 0.0
                
                withAnimation(.easeOut(duration: 0.3)) {
                    strikeProgress = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { // 300ms + 150ms delay
                    withAnimation(.easeIn(duration: 0.3)) {
                        completedOpacity = 0.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        completedTitle = nil
                        
                        withAnimation(.easeIn(duration: 0.3)) {
                            newTitleOpacity = 1.0
                        }
                    }
                }
            }
        }
    }
}


