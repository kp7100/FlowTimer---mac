import SwiftUI
import Combine

@available(macOS 13.0, *)
struct SessionRecoveryModifier: ViewModifier {
    let timerManager: TimerManager
    let isDarkMode: Bool
    var isCompactMode: Bool = false

    @State private var overlayOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var scale: CGFloat = 0.95
    @State private var isShowing: Bool = false
    @State private var titleMessage: String = ""
    @State private var subtitleMessage: String = ""
    @State private var transitionColor: Color = .clear

    func body(content: Content) -> some View {
        content
            .overlay {
                if isShowing {
                    ZStack {
                        // Solid curtain — completely covers the timer during the transition
                        transitionColor
                            .ignoresSafeArea()
                            .opacity(overlayOpacity)
                            .allowsHitTesting(true)

                        VStack(spacing: isCompactMode ? 12 : 8) {
                            if !titleMessage.isEmpty {
                                Text(titleMessage)
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }

                            if !subtitleMessage.isEmpty {
                                Text(subtitleMessage)
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .opacity(textOpacity)
                        .scaleEffect(scale)
                    }
                    .clipShape(RoundedRectangle(
                        cornerRadius: isCompactMode ? AmbientTheme.cornerRadius : 0,
                        style: .continuous
                    ))
                }
            }
            // PassthroughSubject: only surfaces already subscribed at the moment of firing
            // receive this event. Surfaces opened after the fact receive nothing.
            .onReceive(timerManager.recoveryEventPublisher) { event in
                playTransition(for: event)
            }
    }

    private func playTransition(for event: RecoveryEvent) {
        // Read live TimerManager state at the moment of display — never a cached value.
        let themePhase = timerManager.phase

        switch event {
        case .breakResumed:
            titleMessage = "While you were away"
            subtitleMessage = "\(timerManager.remainingTimeFormatted) remaining"
        case .breakCompleted:
            titleMessage = "While you were away"
            subtitleMessage = "Break completed"
        }

        transitionColor = AmbientTheme.current(for: themePhase, isDarkMode: isDarkMode).backgroundColor

        isShowing = true
        overlayOpacity = 0
        textOpacity = 0
        scale = 0.95

        // Fade in
        withAnimation(.easeOut(duration: 0.3)) {
            overlayOpacity = 1.0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
            textOpacity = 1.0
            scale = 1.0
        }

        // Hold, then fade out
        let holdDuration: Double = isCompactMode ? 6.5 : 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
            withAnimation(.easeIn(duration: 0.4)) {
                textOpacity = 0
                scale = 0.98
                overlayOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isShowing = false
            }
        }
    }
}

@available(macOS 13.0, *)
extension View {
    func sessionRecoveryTransition(
        timerManager: TimerManager,
        isDarkMode: Bool = false,
        isCompactMode: Bool = false
    ) -> some View {
        modifier(SessionRecoveryModifier(
            timerManager: timerManager,
            isDarkMode: isDarkMode,
            isCompactMode: isCompactMode
        ))
    }
}
