import SwiftUI

struct AmbientBackgroundModifier: ViewModifier {
    let theme: AmbientTheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AmbientTheme.cornerRadius, style: .continuous)
                    .fill(theme.backgroundColor)
                    .animation(.easeInOut(duration: theme.animationDuration), value: theme.backgroundColor)
            )
            .foregroundColor(theme.foregroundColor)
            .environment(\.ambientTheme, theme)
            .tint(theme.accentColor)
    }
}

extension View {
    /// Applies the ambient background and foreground theme.
    func ambientTheme(_ theme: AmbientTheme) -> some View {
        self.modifier(AmbientBackgroundModifier(theme: theme))
    }
}
