import Foundation
import Observation

@MainActor
@Observable
final class HistoryManager {
    static let shared = HistoryManager()
    
    private(set) var sessions: [SessionRecord] = []
    
    private let fileManager = FileManager.default
    private let fileName = "FlowTimerHistory.json"
    
    private var fileURL: URL? {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.flowtimer.app"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appDirectory.appendingPathComponent(fileName)
    }
    
    private init() {
        loadHistory()
    }
    
    func addSession(_ session: SessionRecord) {
        sessions.append(session)
        saveHistory()
    }
    
    func clearHistory() {
        sessions.removeAll()
        saveHistory()
    }
    
    // Query API
    func allSessions() -> [SessionRecord] { sessions }
    
    func todaySessions() -> [SessionRecord] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.endDate) }
    }
    
    func workSessions() -> [SessionRecord] { sessions.filter { $0.phase == .work } }
    func shortBreakSessions() -> [SessionRecord] { sessions.filter { $0.phase == .shortBreak } }
    func longBreakSessions() -> [SessionRecord] { sessions.filter { $0.phase == .longBreak } }
    
    func totalFocusTime() -> TimeInterval {
        workSessions().reduce(0) { $0 + $1.duration }
    }
    
    func totalBreakTime() -> TimeInterval {
        (shortBreakSessions() + longBreakSessions()).reduce(0) { $0 + $1.duration }
    }
    
    func totalCompletedSessions() -> Int {
        sessions.count
    }
    
    // Persistence
    private func loadHistory() {
        guard let url = fileURL, fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([SessionRecord].self, from: data)
            self.sessions = decoded
        } catch {
            print("Failed to load history gracefully: \(error)")
            // If file is corrupted, we just start with empty history and don't crash.
        }
    }
    
    private func saveHistory() {
        guard let url = fileURL else { return }
        
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
}
