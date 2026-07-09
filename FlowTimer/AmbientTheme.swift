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
                animationDuration: 1.5
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
                animationDuration: 1.5
            )
            
        case .shortBreak:
            let bgTeal = Color(red: 0.10, green: 0.22, blue: 0.19) // Rich eucalyptus
            let buttonTeal = Color(red: 0.06, green: 0.16, blue: 0.14) // Darker teal button
            let hoverTeal = Color(red: 0.04, green: 0.13, blue: 0.11)
            let pressedTeal = Color(red: 0.03, green: 0.10, blue: 0.08)
            let activeTeal = Color(red: 0.30, green: 0.75, blue: 0.65) // Brighter active teal
            
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
                animationDuration: 1.5
            )
            
        case .longBreak:
            let bgLongTeal = Color(red: 0.08, green: 0.19, blue: 0.16) // Slightly darker eucalyptus
            let buttonLongTeal = Color(red: 0.05, green: 0.14, blue: 0.12)
            let hoverLongTeal = Color(red: 0.03, green: 0.11, blue: 0.09)
            let pressedLongTeal = Color(red: 0.02, green: 0.08, blue: 0.07)
            let activeLongTeal = Color(red: 0.28, green: 0.70, blue: 0.60)
            
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
                animationDuration: 1.5
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
