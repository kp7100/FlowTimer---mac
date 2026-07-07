import Foundation

struct EngineSnapshot: Codable {
    let state: TimerState
    let phase: TimerPhase
    let direction: TimerDirection
    let totalSeconds: Int
    let accumulatedSeconds: Double
    let savedAt: Date
}

struct TimerSnapshot: Codable {
    var snapshotVersion: Int = 1
    let currentSession: Int
    let currentPhaseStartDate: Date?
    let engineSnapshot: EngineSnapshot
    var sessionTitle: String?
}
