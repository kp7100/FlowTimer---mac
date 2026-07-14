import SwiftUI
import UniformTypeIdentifiers

struct TodaysFocusView: View {
    @Bindable var taskManager = FocusTaskManager.shared
    @Bindable var timerManager: TimerManager
    @Environment(\.ambientTheme) var theme
    @State private var hoveredTaskId: UUID? = nil
    
    var sortedTasks: [FocusTask] {
        let incomplete = taskManager.todayTasks.filter { !$0.isCompleted }.sorted { $0.order < $1.order }
        let complete = taskManager.todayTasks.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return incomplete + complete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            let incomplete = sortedTasks.filter { !$0.isCompleted }
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
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(task.isCompleted ? theme.secondaryForegroundColor.opacity(0.5) : theme.secondaryForegroundColor)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            
            if isEditing {
                TextField("", text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(task.isCompleted ? theme.secondaryForegroundColor.opacity(0.5) : theme.foregroundColor)
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
                            editingText = task.text
                            isEditing = false
                        }
                    }
                    .onSubmit {
                        taskManager.updateText(id: task.id, newText: editingText)
                        isEditing = false
                    }
                    .onAppear {
                        isFocused = true
                    }
            } else {
                Text(task.text)
                    .font(.system(size: 14))
                    .foregroundColor(task.isCompleted ? theme.secondaryForegroundColor.opacity(0.5) : theme.foregroundColor)
                    .strikethrough(task.isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isEditing = true
                        DispatchQueue.main.async {
                            isFocused = true
                        }
                    }
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
            .opacity(isEditing ? 1.0 : 0.0)
            .disabled(!isEditing)
            
            // Hover Actions
            HStack(spacing: 12) {
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
                    }
                }
                
                Button(action: {
                    timerManager.customSessionTitle = task.text
                    if let tagName = task.tagName,
                       let tag = TagManager.shared.tags.first(where: { $0.name.lowercased() == tagName.lowercased() }) {
                        SettingsManager.shared.settings.selectedTagId = tag.id
                    }
                }) {
                    Image("custom.text.rectangle")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryForegroundColor)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Set as Session Title")
            }
            .opacity(isHovered ? 1.0 : 0.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryForegroundColor.opacity(0.3))
                .frame(width: 20, height: 20)
            
            if isEditing {
                TextField(placeholder, text: $inputText)
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
                        taskManager.addTask(text: textToSave, explicitTagId: tagToSave)
                    }
                    .onAppear {
                        isFocused = true
                    }
            } else {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryForegroundColor.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isEditing = true
                        DispatchQueue.main.async {
                            isFocused = true
                        }
                    }
            }
            
            TagSelectorMenu(selectedTagId: $selectedTagId)
                .opacity(isEditing ? 1.0 : 0.0)
                .disabled(!isEditing)
            
            // Placeholder space for hover actions to keep layout perfectly aligned
            HStack(spacing: 8) {
                Color.clear.frame(width: 20, height: 20)
                Color.clear.frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
