import SwiftUI

struct InlineEditableTitle: View {
    @Binding var title: String
    
    // Customization properties
    var fontSize: CGFloat = 26
    var fontWeight: Font.Weight = .medium
    var alignment: TextAlignment = .center
    var frameAlignment: Alignment = .center
    
    @State private var isEditing = false
    @State private var isHovering = false
    @State private var draftText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: frameAlignment) {
            if isEditing {
                TextField("", text: $draftText)
                    .textFieldStyle(.plain)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .multilineTextAlignment(alignment)
                    .focused($isFocused)
                    .onSubmit {
                        commit()
                    }
                    .onExitCommand {
                        cancel()
                    }
                    .onChange(of: isFocused) { _, newValue in
                        if !newValue && isEditing {
                            commit()
                        }
                    }
            } else {
                Text(title.isEmpty ? "What's your focus?" : title)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundColor(title.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(alignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .contentShape(Rectangle())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture {
                        draftText = title
                        isEditing = true
                        Task {
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            isFocused = true
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .padding(.vertical, 4)
        .padding(.horizontal, 4) // Reduced from 12 so it doesn't push the leading edge too much in the mini timer
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(isHovering && !isEditing ? 0.06 : 0))
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hover
            }
        }
    }
    
    private func commit() {
        title = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditing = false
        isFocused = false
    }
    
    private func cancel() {
        isEditing = false
        isFocused = false
    }
}
