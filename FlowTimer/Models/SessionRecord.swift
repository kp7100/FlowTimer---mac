import Foundation

enum SessionTermination: String, Codable, Hashable {
    case natural
    case reset
    case split
}

struct SessionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let phase: TimerPhase
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let tag: String?
    let pauseCount: Int?
    var continuationOf: UUID?
    var termination: SessionTermination?
    
    /// Pure computed property derived from immutable value data.
    /// Explicitly nonisolated so background actors (e.g. statistics building)
    /// can read it even when the project uses default MainActor isolation.
    nonisolated var pauses: Int {
        pauseCount ?? 0
    }
}
