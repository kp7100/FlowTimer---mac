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
    
    // Date Helpers
    private var todayInterval: DateInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return DateInterval(start: start, end: Date())
    }
    
    private var yesterdayInterval: DateInterval {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? Date()
        return DateInterval(start: yesterdayStart, end: todayStart)
    }
    
    private var weekInterval: DateInterval {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return DateInterval(start: start, end: Date())
    }
    
    private var monthInterval: DateInterval {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        return DateInterval(start: start, end: Date())
    }
    
    // Core filtering
    func sessions(in interval: DateInterval? = nil, phase: TimerPhase = .work) -> [SessionRecord] {
        let filteredByPhase = sessions.filter { $0.phase == phase }
        guard let interval = interval else { return filteredByPhase }
        return filteredByPhase.filter { interval.contains($0.endDate) }
    }
    
    // Focus Time
    func focusTimeToday() -> TimeInterval {
        sessions(in: todayInterval, phase: .work).reduce(0) { $0 + $1.duration }
    }
    
    func focusTimeYesterday() -> TimeInterval {
        sessions(in: yesterdayInterval, phase: .work).reduce(0) { $0 + $1.duration }
    }
    
    func focusTimeThisWeek() -> TimeInterval {
        sessions(in: weekInterval, phase: .work).reduce(0) { $0 + $1.duration }
    }
    
    func focusTimeThisMonth() -> TimeInterval {
        sessions(in: monthInterval, phase: .work).reduce(0) { $0 + $1.duration }
    }
    
    func totalFocusTime() -> TimeInterval {
        sessions(phase: .work).reduce(0) { $0 + $1.duration }
    }
    
    // Flow Extension
    func flowExtensionToday() -> TimeInterval {
        sessions(in: todayInterval, phase: .flowExtension).reduce(0) { $0 + $1.duration }
    }
    
    func flowExtensionYesterday() -> TimeInterval {
        sessions(in: yesterdayInterval, phase: .flowExtension).reduce(0) { $0 + $1.duration }
    }
    
    func flowExtensionThisWeek() -> TimeInterval {
        sessions(in: weekInterval, phase: .flowExtension).reduce(0) { $0 + $1.duration }
    }
    
    func flowExtensionThisMonth() -> TimeInterval {
        sessions(in: monthInterval, phase: .flowExtension).reduce(0) { $0 + $1.duration }
    }
    
    func totalFlowExtension() -> TimeInterval {
        sessions(phase: .flowExtension).reduce(0) { $0 + $1.duration }
    }
    
    func longestFlow() -> TimeInterval {
        sessions(phase: .flowExtension).map { $0.duration }.max() ?? 0
    }
    
    // Session Counts
    func completedWorkSessionsToday() -> Int {
        sessions(in: todayInterval, phase: .work).count
    }
    
    func sessionsYesterday() -> Int {
        sessions(in: yesterdayInterval, phase: .work).count
    }
    
    func completedWorkSessionsThisWeek() -> Int {
        sessions(in: weekInterval, phase: .work).count
    }
    
    func completedWorkSessionsThisMonth() -> Int {
        sessions(in: monthInterval, phase: .work).count
    }
    
    func totalCompletedWorkSessions() -> Int {
        sessions(phase: .work).count
    }
    
    // Tag Queries
    func sessions(for tag: Tag) -> [SessionRecord] {
        sessions.filter { $0.tag == tag.name }
    }
    
    func focusTime(for tag: Tag) -> TimeInterval {
        sessions(for: tag).filter { $0.phase == .work }.reduce(0) { $0 + $1.duration }
    }
    
    func completedSessions(for tag: Tag) -> Int {
        sessions(for: tag).filter { $0.phase == .work }.count
    }
    
    func topTags(limit: Int = 3) -> [(String, TimeInterval)] {
        var dict: [String: TimeInterval] = [:]
        for session in sessions where session.phase == .work || session.phase == .flowExtension {
            if let tag = session.tag {
                dict[tag, default: 0] += session.duration
            }
        }
        let sorted = dict.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(limit))
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
