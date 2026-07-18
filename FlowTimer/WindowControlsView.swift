import SwiftUI

struct WindowControlsView: View {
    let isHoveringWindow: Bool
    var showCloseButton: Bool = true
    var showMiniButton: Bool = true
    var disableAppearanceAnimation: Bool = false
    var onClose: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isHoveringClose = false
    @State private var isHoveringMini = false
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        HStack(spacing: 8) {
            // Close / Hide Button
            if showCloseButton {
                Button(action: {
                    if let onClose = onClose {
                        onClose()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: FlowUIConstants.closeButtonIconSize, weight: .bold))
                        .foregroundColor(isHoveringClose ? .red : theme.foregroundColor.opacity(FlowUIConstants.closeButtonNormalOpacity))
                        .frame(width: FlowUIConstants.closeButtonDiameter, height: FlowUIConstants.closeButtonDiameter)
                        .background(
                            Circle()
                                .fill(isHoveringClose ? Color.red.opacity(FlowUIConstants.closeButtonHoverBackgroundOpacity) : theme.foregroundColor.opacity(FlowUIConstants.closeButtonNormalBackgroundOpacity))
                        )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .onHover { hover in
                    withAnimation(.easeInOut(duration: FlowUIConstants.closeButtonAnimationDuration)) {
                        isHoveringClose = hover
                    }
                }
            }
            
            // Mini Timer Button
            if showMiniButton {
                Button(action: {
                    WindowManager.shared.toggleMiniTimer()
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .foregroundColor(theme.foregroundColor.opacity(0.85))
                        .nativeToolbarIcon(iconSize: 14)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(isHoveringWindow ? 1 : 0)
        .animation(disableAppearanceAnimation ? nil : .easeInOut(duration: 0.18), value: isHoveringWindow)
    }
}
