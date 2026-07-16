import Foundation
import Observation

@MainActor
@Observable
final class HistoryManager {
    static let shared = HistoryManager()
    
    private(set) var sessions: [SessionRecord] = []
    private(set) var historyRevision: Int = 0

    
    private let fileManager = FileManager.default
    private let fileName = "FlowTimerHistory.json"
    
    private var persister: HistoryPersister?
    
    private var fileURL: URL? {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.krishanpareek.FlowTimer"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appDirectory.appendingPathComponent(fileName)
    }
    
    private init() {
        if let url = fileURL {
            persister = HistoryPersister(fileURL: url)
        }
        loadHistory()
    }
    
    func addSession(_ session: SessionRecord) {
        sessions.append(session)
        historyRevision += 1
        saveHistory()

    }
    
    func clearHistory() {
        sessions.removeAll()
        historyRevision += 1
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
        sessions(in: todayInterval, phase: .work).filter { $0.continuationOf == nil }.count
    }
    
    func sessionsYesterday() -> Int {
        sessions(in: yesterdayInterval, phase: .work).filter { $0.continuationOf == nil }.count
    }
    
    func completedWorkSessionsThisWeek() -> Int {
        sessions(in: weekInterval, phase: .work).filter { $0.continuationOf == nil }.count
    }
    
    func completedWorkSessionsThisMonth() -> Int {
        sessions(in: monthInterval, phase: .work).filter { $0.continuationOf == nil }.count
    }
    
    func totalCompletedWorkSessions() -> Int {
        sessions(phase: .work).filter { $0.continuationOf == nil }.count
    }
    
    // Tag Queries
    func sessions(for tag: Tag) -> [SessionRecord] {
        sessions.filter { $0.tag == tag.name }
    }
    
    func focusTime(for tag: Tag) -> TimeInterval {
        sessions(for: tag).filter { $0.phase == .work }.reduce(0) { $0 + $1.duration }
    }
    
    func completedSessions(for tag: Tag) -> Int {
        sessions(for: tag).filter { $0.phase == .work && $0.continuationOf == nil }.count
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
        var logOutput = "====== HISTORY MANAGER DIAGNOSTICS ======\n"
        logOutput += "Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")\n"
        
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        
        let bundleID = Bundle.main.bundleIdentifier ?? "com.krishanpareek.FlowTimer"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        let logURL = appDirectory.appendingPathComponent("history_log.txt")
        
        logOutput += "Application Support: \(appSupportURL.path)\n"
        
        guard let url = fileURL else {
            logOutput += "ERROR: fileURL is nil\n=========================================\n"
            try? logOutput.write(to: logURL, atomically: true, encoding: .utf8)
            return
        }
        
        logOutput += "Resolved History Path: \(url.path)\n"
        let exists = fileManager.fileExists(atPath: url.path)
        logOutput += "File Exists: \(exists)\n"
        
        if exists {
            do {
                let attr = try fileManager.attributesOfItem(atPath: url.path)
                let size = attr[.size] as? UInt64 ?? 0
                logOutput += "File Size: \(size) bytes\n"
            } catch {
                logOutput += "Failed to read file size: \(error)\n"
            }
        }
        
        guard exists else {
            logOutput += "=========================================\n"
            let existingLog = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            try? (existingLog + logOutput).write(to: logURL, atomically: true, encoding: .utf8)
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([SessionRecord].self, from: data)
            self.sessions = decoded
            logOutput += "Successfully loaded \(decoded.count) SessionRecords.\n"
            if let first = decoded.first, let last = decoded.last {
                logOutput += "First Session Date: \(first.startDate)\n"
                logOutput += "Last Session Date: \(last.startDate)\n"
            }
            logOutput += "HistoryManager.shared.sessions.count: \(self.sessions.count)\n"
        } catch {
            logOutput += "Failed to load history gracefully: \(error)\n"
        }
        logOutput += "=========================================\n"
        
        let existingLog = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        try? (existingLog + logOutput).write(to: logURL, atomically: true, encoding: .utf8)
    }
    
    private func saveHistory() {
        guard let persister = persister else { return }
        let snapshot = sessions // Value copy for thread safety
        Task {
            await persister.save(sessions: snapshot)
        }
    }
}
