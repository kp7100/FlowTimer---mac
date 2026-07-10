import SwiftUI

struct SharedSessionTitleView: View {
    @Bindable var timerManager: TimerManager
    
    var fontSize: CGFloat = 26
    var fontWeight: Font.Weight = .medium
    var alignment: TextAlignment = .center
    var frameAlignment: Alignment = .center
    
    var body: some View {
        if timerManager.phase == .work || timerManager.phase == .flowExtension {
            InlineEditableTitle(
                displayTitle: timerManager.sessionTitle,
                customTitle: Binding(
                    get: { timerManager.customSessionTitle },
                    set: { timerManager.customSessionTitle = $0 }
                ),
                fontSize: fontSize,
                fontWeight: fontWeight,
                alignment: alignment,
                frameAlignment: frameAlignment
            )
        } else {
            WellnessPromptView(
                timerManager: timerManager,
                fontSize: fontSize,
                fontWeight: fontWeight,
                alignment: frameAlignment,
                textAlignment: alignment
            )
        }
    }
}
