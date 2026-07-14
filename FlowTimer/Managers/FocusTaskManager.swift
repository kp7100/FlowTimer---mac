import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class FocusTaskManager {
    static let shared = FocusTaskManager()
    private let userDefaultsKey = "FlowTimerFocusTasks"
    private var allTasks: [FocusTask] = []
    
    // Dependencies
    private let settingsManager: SettingsManager
    private let tagManager: TagManager
    
    init(settingsManager: SettingsManager? = nil, tagManager: TagManager? = nil) {
        self.settingsManager = settingsManager ?? .shared
        self.tagManager = tagManager ?? .shared
        loadTasks()
    }
    
    // MARK: - Day Scoping
    
    static func currentFocusDayKey(now: Date, resetHour: Int, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: now)
        var referenceDate = now
        
        // If the current hour is strictly less than the reset hour, we belong to the "previous" day
        if hour < resetHour {
            referenceDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        
        return formatter.string(from: referenceDate)
    }
    
    var currentFocusDay: String {
        FocusTaskManager.currentFocusDayKey(
            now: Date(),
            resetHour: settingsManager.settings.focusTaskResetHour,
            calendar: Calendar.current
        )
    }
    
    // Computed property returning only active tasks for the current focus day, sorted by order
    var todayTasks: [FocusTask] {
        allTasks
            .filter { $0.focusDay == currentFocusDay }
            .sorted { $0.order < $1.order }
    }
    
    // MARK: - Core Logic
    
    func addTask(text: String, explicitTagId: UUID? = nil) {
        let dayKey = currentFocusDay
        let currentCount = allTasks.filter { $0.focusDay == dayKey }.count
        
        guard currentCount < 3 else { return }
        
        let parsedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var tagName: String? = nil
        
        if let explicitId = explicitTagId, let tag = TagManager.shared.tags.first(where: { $0.id == explicitId }) {
            tagName = tag.name
        }
        
        guard !parsedText.isEmpty else { return }
        
        let newTask = FocusTask(
            id: UUID(),
            text: parsedText,
            isCompleted: false,
            order: currentCount,
            focusDay: dayKey,
            tagName: tagName
        )
        
        allTasks.append(newTask)
        saveTasks()
    }
    
    func updateText(id: UUID, newText: String) {
        guard let index = allTasks.firstIndex(where: { $0.id == id }) else { return }
        
        let parsedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if parsedText.isEmpty {
            deleteTask(id: id)
            return
        }
        
        allTasks[index].text = parsedText
        // Note: updateText no longer manipulates the tag. Tags are set explicitly via setTag.
        
        saveTasks()
    }
    
    func setTag(id: UUID, tagName: String?) {
        guard let globalIndex = allTasks.firstIndex(where: { $0.id == id }) else { return }
        allTasks[globalIndex].tagName = tagName
        saveTasks()
    }
    
    func toggleCompletion(id: UUID) {
        guard let index = allTasks.firstIndex(where: { $0.id == id }) else { return }
        allTasks[index].isCompleted.toggle()
        allTasks[index].completedAt = allTasks[index].isCompleted ? Date() : nil
        saveTasks()
    }
    
    func deleteTask(id: UUID) {
        guard let taskToDelete = allTasks.first(where: { $0.id == id }) else { return }
        let dayKey = taskToDelete.focusDay
        
        allTasks.removeAll(where: { $0.id == id })
        reindexTasks(for: dayKey)
        saveTasks()
    }
    
    func move(from source: IndexSet, to destination: Int) {
        var dayTasks = todayTasks
        dayTasks.move(fromOffsets: source, toOffset: destination)
        
        for (newOrder, task) in dayTasks.enumerated() {
            if let globalIndex = allTasks.firstIndex(where: { $0.id == task.id }) {
                allTasks[globalIndex].order = newOrder
            }
        }
        saveTasks()
    }
    
    func moveUp(id: UUID) {
        let incomplete = todayTasks.filter { !$0.isCompleted }.sorted { $0.order < $1.order }
        guard let index = incomplete.firstIndex(where: { $0.id == id }), index > 0 else { return }
        
        let previousTask = incomplete[index - 1]
        let currentTask = incomplete[index]
        
        if let g1 = allTasks.firstIndex(where: { $0.id == currentTask.id }),
           let g2 = allTasks.firstIndex(where: { $0.id == previousTask.id }) {
            let temp = allTasks[g1].order
            allTasks[g1].order = allTasks[g2].order
            allTasks[g2].order = temp
            saveTasks()
        }
    }
    
    func moveDown(id: UUID) {
        let incomplete = todayTasks.filter { !$0.isCompleted }.sorted { $0.order < $1.order }
        guard let index = incomplete.firstIndex(where: { $0.id == id }), index < incomplete.count - 1 else { return }
        
        let nextTask = incomplete[index + 1]
        let currentTask = incomplete[index]
        
        if let g1 = allTasks.firstIndex(where: { $0.id == currentTask.id }),
           let g2 = allTasks.firstIndex(where: { $0.id == nextTask.id }) {
            let temp = allTasks[g1].order
            allTasks[g1].order = allTasks[g2].order
            allTasks[g2].order = temp
            saveTasks()
        }
    }
    
    // MARK: - Helpers
    
    private func reindexTasks(for dayKey: String) {
        let dayTasks = allTasks
            .filter { $0.focusDay == dayKey }
            .sorted { $0.order < $1.order }
            
        for (index, task) in dayTasks.enumerated() {
            if let globalIndex = allTasks.firstIndex(where: { $0.id == task.id }) {
                allTasks[globalIndex].order = index
            }
        }
    }

    // MARK: - Persistence
    
    private func saveTasks() {
        if let data = try? JSONEncoder().encode(allTasks) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedTasks = try? JSONDecoder().decode([FocusTask].self, from: data) {
            self.allTasks = savedTasks
        }
    }
}
