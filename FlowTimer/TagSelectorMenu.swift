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
        } label: {
            Image(systemName: hasTag ? "tag.fill" : "tag")
                .font(.system(size: 14))
                .foregroundColor(hasTag ? currentTheme.accentColor : currentTheme.secondaryForegroundColor)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
