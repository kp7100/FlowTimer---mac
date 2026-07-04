import SwiftUI

struct ManageTagsView: View {
    @Bindable var tagManager = TagManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var newTagName: String = ""
    @State private var editingTagId: UUID? = nil
    @State private var editingTagName: String = ""
    
    var body: some View {
        VStack {
            Text("Manage Tags")
                .font(.headline)
                .padding()
            
            HStack {
                TextField("New Tag...", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !newTagName.isEmpty {
                            tagManager.addTag(name: newTagName)
                            newTagName = ""
                        }
                    }
                Button("Add") {
                    if !newTagName.isEmpty {
                        tagManager.addTag(name: newTagName)
                        newTagName = ""
                    }
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            
            List {
                ForEach(tagManager.tags) { tag in
                    HStack {
                        if editingTagId == tag.id {
                            TextField("Tag Name", text: $editingTagName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    tagManager.renameTag(id: tag.id, newName: editingTagName)
                                    editingTagId = nil
                                }
                            Button("Save") {
                                tagManager.renameTag(id: tag.id, newName: editingTagName)
                                editingTagId = nil
                            }
                        } else {
                            Text(tag.name)
                            Spacer()
                            Button {
                                editingTagId = tag.id
                                editingTagName = tag.name
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                tagManager.deleteTag(id: tag.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                    }
                }
            }
            
            Button("Done") {
                dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 400)
    }
}
