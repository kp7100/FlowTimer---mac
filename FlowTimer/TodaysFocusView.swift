import SwiftUI
import UniformTypeIdentifiers

struct TodaysFocusView: View {
    @Bindable var taskManager = FocusTaskManager.shared
    @Bindable var timerManager: TimerManager
    @Environment(\.ambientTheme) var theme
    @State private var hoveredTaskId: UUID? = nil
    
    var body: some View {
        let sortedTasks = taskManager.sortedTasks
        let incomplete = sortedTasks.filter { !$0.isCompleted }

        VStack(spacing: 0) {
            ForEach(sortedTasks) { task in
                FocusTaskRowView(
                    task: task,
                    taskManager: taskManager,
                    timerManager: timerManager,
                    isHovered: hoveredTaskId == task.id,
                    isFirstIncomplete: task.id == incomplete.first?.id,
                    isLastIncomplete: task.id == incomplete.last?.id,
                    onHover: { hovering in
                        if hovering {
                            hoveredTaskId = task.id
                        } else if hoveredTaskId == task.id {
                            hoveredTaskId = nil
                        }
                    }
                )
            }
            
            if sortedTasks.count < 3 {
                FocusTaskInputRowView(taskManager: taskManager, currentCount: sortedTasks.count)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sortedTasks)
        .padding(.vertical, 8)
        .background(
            Color.white.opacity(0.0001)
                .onTapGesture {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
        )
    }
}
struct FocusTaskRowView: View {
    let task: FocusTask
    let taskManager: FocusTaskManager
    let timerManager: TimerManager
    let isHovered: Bool
    let isFirstIncomplete: Bool
    let isLastIncomplete: Bool
    let onHover: (Bool) -> Void
    
    @State private var editingText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    @Environment(\.ambientTheme) var theme
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                taskManager.toggleCompletion(id: task.id)
                if !task.isCompleted, timerManager.customSessionTitle == task.text {
                    NotificationCenter.default.post(name: .sessionTitleCompleted, object: task.text)
                    timerManager.customSessionTitle = nil
                }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(task.isCompleted ? theme.secondaryForegroundColor.opacity(0.5) : theme.secondaryForegroundColor)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            
            Group {
                if isEditing {
                    SharedInlineTextField(
                        displayTitle: "",
                        text: $editingText,
                        placeholder: "",
                        placeholderColor: NSColor(theme.secondaryForegroundColor.opacity(0.5)),
                        font: .systemFont(ofSize: 14),
                        textColor: NSColor(task.isCompleted ? theme.secondaryForegroundColor.opacity(0.5) : theme.foregroundColor),
                        alignment: .left,
                        isEditing: $isEditing,
                        onCommit: { newText in
                            taskManager.updateText(id: task.id, newText: newText)
                            isEditing = false
                        }
                    )
                    .padding(.trailing, !task.isCompleted ? 104 : 0)
                } else {
                    Text(task.text)
                        .font(.system(size: 14))
                        .foregroundColor(task.isCompleted ? theme.secondaryForegroundColor.opacity(0.5) : theme.foregroundColor)
                        .strikethrough(task.isCompleted)
                        .lineLimit(1)
                        .padding(.trailing, !task.isCompleted ? 104 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                isEditing = true
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
            .overlay(alignment: .trailing) {
                if !task.isCompleted {
                    HStack(spacing: 8) {
                        if !isFirstIncomplete {
                            Button(action: {
                                taskManager.moveUp(id: task.id)
                            }) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.secondaryForegroundColor.opacity(0.8))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if !isLastIncomplete {
                            Button(action: {
                                taskManager.moveDown(id: task.id)
                            }) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.secondaryForegroundColor.opacity(0.8))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        TagSelectorMenu(selectedTagId: Binding(
                            get: {
                                guard let tagName = task.tagName else { return nil }
                                return TagManager.shared.tags.first(where: { $0.name.lowercased() == tagName.lowercased() })?.id
                            },
                            set: { newId in
                                if let newId = newId, let tag = TagManager.shared.tags.first(where: { $0.id == newId }) {
                                    taskManager.setTag(id: task.id, tagName: tag.name)
                                } else {
                                    taskManager.setTag(id: task.id, tagName: nil)
                                }
                            }
                        ))
                        
                        Button(action: {
                            timerManager.customSessionTitle = task.text
                            if let tagName = task.tagName,
                               let tag = TagManager.shared.tags.first(where: { $0.name.lowercased() == tagName.lowercased() }) {
                                SettingsManager.shared.settings.selectedTagId = tag.id
                            }
                        }) {
                            Image(systemName: "inset.filled.topthird.rectangle")
                                .foregroundColor(theme.foregroundColor.opacity(0.85))
                                .nativeToolbarIcon()
                        }
                        .buttonStyle(.plain)
                        .help("Set as Session Title")
                    }
                    .opacity((isHovered || isEditing) ? 1.0 : 0.0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.foregroundColor.opacity(isHovered ? 0.06 : 0.0))
        )
        .onHover(perform: onHover)
        .onAppear {
            editingText = task.text
        }
        .onChange(of: task.text) { _, newText in
            editingText = newText
        }
    }
}

struct FocusTaskInputRowView: View {
    let taskManager: FocusTaskManager
    let currentCount: Int
    @State private var inputText: String = ""
    @State private var isEditing: Bool = false
    @State private var selectedTagId: UUID? = nil
    @FocusState private var isFocused: Bool
    @Environment(\.ambientTheme) var theme
    
    var placeholder: String {
        switch currentCount {
        case 0: return "Start with your top priority..."
        case 1: return "Add another priority..."
        default: return "Anything else?"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(theme.secondaryForegroundColor.opacity(0.3))
                .frame(width: 30, height: 30)
            
            Group {
                if isEditing {
                    TextField("", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(theme.foregroundColor)
                        .focused($isFocused)
                        .onReceive(NotificationCenter.default.publisher(for: NSTextField.textDidBeginEditingNotification)) { obj in
                            if let textField = obj.object as? NSTextField {
                                DispatchQueue.main.async {
                                    textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
                                }
                            }
                        }
                        .onChange(of: isFocused) { _, focused in
                            if !focused {
                                isEditing = false
                                inputText = ""
                            }
                        }
                        .onSubmit {
                            let textToSave = inputText
                            let tagToSave = selectedTagId
                            inputText = ""
                            selectedTagId = nil
                            isEditing = false
                            if !textToSave.trimmingCharacters(in: .whitespaces).isEmpty {
                                taskManager.addTask(text: textToSave, explicitTagId: tagToSave)
                            }
                        }
                        .onAppear {
                            isFocused = true
                        }
                        .padding(.trailing, 34)
                } else {
                    Text(placeholder)
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryForegroundColor.opacity(0.5))
                        .lineLimit(1)
                        .padding(.trailing, 34)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeometryReader { geo in Color.clear.onAppear { print("MEASURE - Text Container (Group) width: \(geo.size.width)") } })
            .contentShape(Rectangle())
            .onTapGesture {
                isEditing = true
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
            .overlay(alignment: .trailing) {
                TagSelectorMenu(selectedTagId: $selectedTagId)
                    .opacity(isEditing ? 1.0 : 0.0)
                    .disabled(!isEditing)
                    .background(GeometryReader { geo in Color.clear.onAppear { print("MEASURE - TagSelectorMenu width: \(geo.size.width)") } })
            }
        }
        .background(GeometryReader { geo in Color.clear.onAppear { print("MEASURE - Entire Input Row width: \(geo.size.width)") } })
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
