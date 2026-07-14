import SwiftUI

struct CustomDurationsView: View {
    @State private var workDuration: Int
    @State private var shortBreak: Int
    @State private var longBreak: Int
    @State private var flowExtension: Int
    
    init() {
        let settings = SettingsManager.shared.settings
        _workDuration = State(initialValue: settings.workDuration / 60)
        _shortBreak = State(initialValue: settings.shortBreakDuration / 60)
        _longBreak = State(initialValue: settings.longBreakDuration / 60)
        _flowExtension = State(initialValue: (settings.flowExtensionLimit ?? (15 * 60)) / 60)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Custom Durations")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
            
            VStack(spacing: 16) {
                // Work
                VStack {
                    DurationSlider(
                        title: "Work",
                        value: $workDuration,
                        range: 5...120
                    )
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Breaks
                VStack(spacing: 16) {
                    DurationSlider(
                        title: "Short Break",
                        value: $shortBreak,
                        range: 1...90
                    )
                    
                    Divider()
                        .padding(.horizontal, 4)
                    
                    DurationSlider(
                        title: "Long Break",
                        value: $longBreak,
                        range: 1...90
                    )
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Flow Extension
                VStack {
                    DurationSlider(
                        title: "Flow Extension Limit",
                        value: $flowExtension,
                        range: 1...90
                    )
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
            }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    WindowManager.shared.hideCustomDurationsWindow()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Done") {
                    SettingsManager.shared.settings.workDuration = workDuration * 60
                    SettingsManager.shared.settings.shortBreakDuration = shortBreak * 60
                    SettingsManager.shared.settings.longBreakDuration = longBreak * 60
                    SettingsManager.shared.settings.flowExtensionLimit = flowExtension * 60
                    WindowManager.shared.hideCustomDurationsWindow()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

struct DurationSlider: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                Spacer()
                Text("\(value) min")
                    .font(.system(size: 14, weight: .medium))
            }
            
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int(round($0)) }
                ),
                in: range
            )
            .tint(Color.accentColor)
        }
    }
}
