import SwiftUI

struct TextFieldPrototypeView: View {
    @State private var text = "Prototype Title"
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Native SwiftUI Focus Prototype")
                .font(.headline)
            
            TextField("Session Title", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                )
                .onChange(of: isFocused) { _, newValue in
                    if newValue {
                        WindowLifecycleObserver.shared.logEvent("✏️ Prototype TextField gained focus")
                    } else {
                        WindowLifecycleObserver.shared.logEvent("❌ Prototype TextField lost focus")
                    }
                }
            
            Text("Click the text field above to edit.\nTest: Space, Escape, Enter, Switching Spaces.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Unfocus") {
                isFocused = false
            }
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}
