import SwiftUI

struct WindowControlsView: View {
    let isHoveringWindow: Bool
    var showCloseButton: Bool = true
    var showMiniButton: Bool = true
    var onClose: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    
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
                .onHover { hover in
                    withAnimation(.easeInOut(duration: FlowUIConstants.closeButtonAnimationDuration)) {
                        isHoveringClose = hover
                    }
                }
            }
            
            // Mini Timer Button
            if showMiniButton {
                Button(action: {
                    if let onClose = onClose {
                        onClose()
                    } else {
                        dismiss()
                    }
                    WindowManager.shared.showMiniTimer()
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: FlowUIConstants.closeButtonIconSize, weight: .bold))
                        .foregroundColor(isHoveringMini ? theme.accentColor : theme.foregroundColor.opacity(FlowUIConstants.closeButtonNormalOpacity))
                        .frame(width: FlowUIConstants.closeButtonDiameter, height: FlowUIConstants.closeButtonDiameter)
                        .background(
                            Circle()
                                .fill(isHoveringMini ? theme.accentColor.opacity(FlowUIConstants.closeButtonHoverBackgroundOpacity) : theme.foregroundColor.opacity(FlowUIConstants.closeButtonNormalBackgroundOpacity))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hover in
                    withAnimation(.easeInOut(duration: FlowUIConstants.closeButtonAnimationDuration)) {
                        isHoveringMini = hover
                    }
                }
            }
        }
        .opacity(isHoveringWindow ? 1 : 0)
        .animation(.easeInOut(duration: 0.18), value: isHoveringWindow)
    }
}
