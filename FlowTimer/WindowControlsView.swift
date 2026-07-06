import SwiftUI

struct WindowControlsView: View {
    let isHoveringWindow: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var isHoveringClose = false
    @State private var isHoveringMini = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Close / Hide Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isHoveringClose ? .red : .primary.opacity(0.6))
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(isHoveringClose ? Color.red.opacity(0.15) : Color.primary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHoveringClose = hover
                }
            }
            
            // Mini Timer Button
            Button(action: {
                // Action: Switch to mini window (placeholder)
                print("Switch to mini timer")
            }) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isHoveringMini ? Color.accentColor : .primary.opacity(0.6))
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(isHoveringMini ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHoveringMini = hover
                }
            }
        }
        .opacity(isHoveringWindow ? 1 : 0)
        .animation(.easeInOut(duration: 0.18), value: isHoveringWindow)
    }
}
