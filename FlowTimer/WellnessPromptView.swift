import SwiftUI

struct WellnessPromptView: View {
    let timerManager: TimerManager
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let alignment: Alignment
    let textAlignment: TextAlignment
    
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        Group {
            if timerManager.phase == .shortBreak {
                if WellnessPromptProvider.shared.isPromptActive, let message = WellnessPromptProvider.shared.currentMessage {
                    Text(message.text)
                        .font(.system(size: fontSize, weight: fontWeight))
                        .foregroundColor(theme.foregroundColor)
                        .frame(maxWidth: .infinity, alignment: alignment)
                        .multilineTextAlignment(textAlignment)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .transition(.opacity)
                } else {
                    Text("Short Break")
                        .font(.system(size: fontSize, weight: fontWeight))
                        .foregroundColor(theme.foregroundColor)
                        .frame(maxWidth: .infinity, alignment: alignment)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .transition(.opacity)
                }
            } else {
                Text("Long Break")
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundColor(theme.foregroundColor)
                    .frame(maxWidth: .infinity, alignment: alignment)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .task(id: timerManager.phaseInstanceID) {
            let context = WellnessContext(
                phaseID: timerManager.phaseInstanceID,
                phase: timerManager.phase,
                currentSession: timerManager.currentSession,
                sessionsPerCycle: timerManager.totalSessions,
                adaptivePayload: timerManager.recentAdaptiveBreakPayload
            )
            
            
            // The provider handles caching and the 25-second display timer globally
            _ = WellnessPromptProvider.shared.prompt(for: context)
        }
    }
}
