import SwiftUI

struct AmbientTheme: Equatable {
    let backgroundColor: Color
    let foregroundColor: Color
    let secondaryForegroundColor: Color
    let primaryColor: Color
    
    let buttonBackground: Color
    let buttonHoverBackground: Color
    let buttonPressedBackground: Color
    let buttonForeground: Color
    
    let takeBreakButtonBackground: Color
    
    let activeDotColor: Color
    let inactiveDotColor: Color
    
    let accentColor: Color
    let iconColor: Color
    
    let menuBarPillBackground: Color
    let menuBarPillForeground: Color
    
    let timerTextColor: Color
    
    let animationDuration: Double
    
    static let cornerRadius: CGFloat = 12
    static func flowColor(isDarkMode: Bool) -> Color {
        return isDarkMode 
            ? Color(red: 49/255, green: 93/255, blue: 233/255) // #315DE9
            : Color(red: 59/255, green: 120/255, blue: 226/255) // #3B78E2
    }

    static func current(for phase: TimerPhase, isDarkMode: Bool) -> AmbientTheme {
        switch phase {
        case .work:
            return AmbientTheme(
                backgroundColor: Color(NSColor.windowBackgroundColor),
                foregroundColor: .primary,
                secondaryForegroundColor: .secondary,
                primaryColor: .accentColor,
                buttonBackground: .accentColor,
                buttonHoverBackground: .accentColor.opacity(0.85),
                buttonPressedBackground: .accentColor.opacity(0.7),
                buttonForeground: .white,
                takeBreakButtonBackground: .accentColor,
                activeDotColor: .accentColor,
                inactiveDotColor: Color.secondary.opacity(0.3),
                accentColor: .accentColor,
                iconColor: .secondary,
                menuBarPillBackground: isDarkMode ? .black : .white,
                menuBarPillForeground: isDarkMode ? .white : .black,
                timerTextColor: .primary,
                animationDuration: 0.5
            )
            
        case .flowExtension:
            let flowColor = AmbientTheme.flowColor(isDarkMode: isDarkMode)
            let buttonBlue = flowColor.opacity(0.92) // Pause button
            let takeBreakBlue = flowColor.opacity(0.82) // Take Break button
            let hoverBlue = flowColor.opacity(0.85)
            let pressedBlue = flowColor.opacity(0.7)
            
            return AmbientTheme(
                backgroundColor: Color(NSColor.windowBackgroundColor),
                foregroundColor: .primary,
                secondaryForegroundColor: .secondary,
                primaryColor: flowColor,
                buttonBackground: buttonBlue,
                buttonHoverBackground: hoverBlue,
                buttonPressedBackground: pressedBlue,
                buttonForeground: .white,
                takeBreakButtonBackground: takeBreakBlue,
                activeDotColor: flowColor.opacity(0.78),
                inactiveDotColor: flowColor.opacity(0.22),
                accentColor: flowColor.opacity(0.88), // Tag selector
                iconColor: flowColor.opacity(0.8),
                menuBarPillBackground: flowColor,
                menuBarPillForeground: .white,
                timerTextColor: flowColor,
                animationDuration: 0.5
            )
            
        case .shortBreak:
            let bgTeal = Color(red: 0.16, green: 0.32, blue: 0.28) // Rich eucalyptus (lighter)
            let buttonTeal = Color(red: 0.12, green: 0.26, blue: 0.23) // Darker teal button
            let hoverTeal = Color(red: 0.10, green: 0.23, blue: 0.20)
            let pressedTeal = Color(red: 0.08, green: 0.20, blue: 0.17)
            let activeTeal = Color(red: 0.35, green: 0.80, blue: 0.70) // Brighter active teal
            
            return AmbientTheme(
                backgroundColor: bgTeal,
                foregroundColor: .white,
                secondaryForegroundColor: .white.opacity(0.85),
                primaryColor: activeTeal,
                buttonBackground: buttonTeal,
                buttonHoverBackground: hoverTeal,
                buttonPressedBackground: pressedTeal,
                buttonForeground: .white,
                takeBreakButtonBackground: buttonTeal,
                activeDotColor: activeTeal,
                inactiveDotColor: .white.opacity(0.2),
                accentColor: activeTeal,
                iconColor: .white.opacity(0.8),
                menuBarPillBackground: bgTeal,
                menuBarPillForeground: .white,
                timerTextColor: .white,
                animationDuration: 0.5
            )
            
        case .longBreak:
            let bgLongTeal = Color(red: 0.14, green: 0.29, blue: 0.25) // Slightly darker eucalyptus (lighter)
            let buttonLongTeal = Color(red: 0.10, green: 0.23, blue: 0.20)
            let hoverLongTeal = Color(red: 0.08, green: 0.20, blue: 0.17)
            let pressedLongTeal = Color(red: 0.06, green: 0.17, blue: 0.14)
            let activeLongTeal = Color(red: 0.33, green: 0.75, blue: 0.65)
            
            return AmbientTheme(
                backgroundColor: bgLongTeal,
                foregroundColor: .white,
                secondaryForegroundColor: .white.opacity(0.85),
                primaryColor: activeLongTeal,
                buttonBackground: buttonLongTeal,
                buttonHoverBackground: hoverLongTeal,
                buttonPressedBackground: pressedLongTeal,
                buttonForeground: .white,
                takeBreakButtonBackground: buttonLongTeal,
                activeDotColor: activeLongTeal,
                inactiveDotColor: .white.opacity(0.2),
                accentColor: activeLongTeal,
                iconColor: .white.opacity(0.8),
                menuBarPillBackground: bgLongTeal,
                menuBarPillForeground: .white,
                timerTextColor: .white,
                animationDuration: 0.5
            )
        }
    }
}

private struct AmbientThemeKey: EnvironmentKey {
    static let defaultValue: AmbientTheme = AmbientTheme.current(for: .work, isDarkMode: false)
}

extension EnvironmentValues {
    var ambientTheme: AmbientTheme {
        get { self[AmbientThemeKey.self] }
        set { self[AmbientThemeKey.self] = newValue }
    }
}

struct WellnessIconProvider {
    static func icon(for state: FlowWellnessState) -> String {
        switch state {
        case .coffee: return "cup.and.saucer.fill"
        case .stretch: return "figure.cooldown"
        case .water: return "drop.fill"
        case .eyes: return "eye.fill"
        case .walk: return "figure.walk"
        }
    }
}

struct PrimaryAmbientButtonStyle: ButtonStyle {
    @Environment(\.ambientTheme) var theme
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(theme.buttonForeground)
            .padding(.horizontal, 24)
            .frame(height: 44)
            .background(
                configuration.isPressed ? theme.buttonPressedBackground :
                (isHovered ? theme.buttonHoverBackground : theme.buttonBackground)
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
