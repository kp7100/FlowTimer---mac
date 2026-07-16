import SwiftUI

struct TagSelectorMenu: View {
    @Binding var selectedTagId: UUID?
    @Bindable var tagManager = TagManager.shared
    @Environment(\.ambientTheme) var currentTheme
    
    var body: some View {
        let hasTag = selectedTagId != nil
        Menu {
            Picker("Selected Tag", selection: $selectedTagId) {
                Text("None").tag(UUID?.none)
                Divider()
                ForEach(tagManager.tags) { tag in
                    Text(tag.name).tag(Optional(tag.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: hasTag ? "tag.fill" : "tag")
                .foregroundColor(hasTag ? currentTheme.accentColor : currentTheme.secondaryForegroundColor)
                .nativeToolbarIcon()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
