import SwiftUI
import AppKit

struct FlowUIConstants {
    // MARK: - Close Button
    static let closeButtonDiameter: CGFloat = 16.0
    static let closeButtonIconSize: CGFloat = 9.5
    
    static let closeButtonNormalOpacity: Double = 0.6
    static let closeButtonNormalBackgroundOpacity: Double = 0.08
    
    static let closeButtonHoverOpacity: Double = 1.0
    static let closeButtonHoverBackgroundOpacity: Double = 0.15
    
    static let closeButtonAnimationDuration: TimeInterval = 0.1
    
    // MARK: - AppKit Specific Colors
    static var closeButtonNormalTintColor: NSColor {
        NSColor(white: 1.0, alpha: closeButtonNormalOpacity)
    }
    
    static var closeButtonNormalBackgroundColor: CGColor {
        NSColor(white: 1.0, alpha: closeButtonNormalBackgroundOpacity).cgColor
    }
    
    static var closeButtonHoverTintColor: NSColor {
        NSColor.systemRed
    }
    
    static var closeButtonHoverBackgroundColor: CGColor {
        NSColor.systemRed.withAlphaComponent(closeButtonHoverBackgroundOpacity).cgColor
    }
    
}

struct NativeToolbarIconModifier: ViewModifier {
    @State private var isHovering = false
    var iconSize: CGFloat = 19
    @Environment(\.ambientTheme) var theme
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: iconSize, weight: .medium))
            .frame(width: 30, height: 30)
            .contentShape(Circle())
            .background(
                Circle()
                    .fill(theme.foregroundColor.opacity(isHovering ? 0.08 : 0.0))
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .pointingHandCursor()
    }
}

extension View {
    func nativeToolbarIcon(iconSize: CGFloat = 19) -> some View {
        self.modifier(NativeToolbarIconModifier(iconSize: iconSize))
    }
}

struct NativeCursorModifier: ViewModifier {
    var cursor: NSCursor
    var isEnabled: Bool
    @State private var hasPushed = false
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                self.isHovering = hovering
                updateCursor()
            }
            .onChange(of: isEnabled) { _, _ in
                updateCursor()
            }
            .onDisappear {
                if hasPushed {
                    NSCursor.pop()
                    hasPushed = false
                }
            }
    }

    private func updateCursor() {
        if isHovering && isEnabled {
            if !hasPushed {
                cursor.push()
                hasPushed = true
            }
        } else {
            if hasPushed {
                NSCursor.pop()
                hasPushed = false
            }
        }
    }
}

extension View {
    func pointingHandCursor(isEnabled: Bool = true) -> some View {
        self.modifier(NativeCursorModifier(cursor: NSCursor.pointingHand, isEnabled: isEnabled))
    }
    
    func iBeamCursor(isEnabled: Bool = true) -> some View {
        self.modifier(NativeCursorModifier(cursor: NSCursor.iBeam, isEnabled: isEnabled))
    }
}
