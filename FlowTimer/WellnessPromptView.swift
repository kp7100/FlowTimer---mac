import SwiftUI

struct WellnessPromptView: View {
    let timerManager: TimerManager
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let alignment: Alignment
    let textAlignment: TextAlignment
    
    @Environment(\.ambientTheme) var theme
    
    @State private var currentMessage: WellnessMessage?
    
    var body: some View {
        Group {
            if timerManager.phase == .shortBreak {
                if WellnessPromptProvider.shared.isPromptActive, let message = currentMessage {
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
        .task(id: timerManager.phaseStartDate) {
            let context = WellnessContext(
                phaseID: timerManager.phaseStartDate,
                phase: timerManager.phase,
                currentSession: timerManager.currentSession,
                sessionsPerCycle: timerManager.totalSessions
            )
            
            // The provider handles caching and the 25-second display timer globally
            currentMessage = WellnessPromptProvider.shared.prompt(for: context)
        }
    }
}
