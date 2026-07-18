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
    
    /// The single canonical definition of completed planned work.
    ///
    /// In the Logical Focus Session model, Flow Extension is a continuation of
    /// a focus block, NOT a separate session. This property decouples the concept
    /// of "Did the user hit their 25-minute goal?" from "How long did they focus?"
    ///
    /// - Returns: `true` ONLY if the planned Work phase completed naturally.
    /// Cancelling a subsequent Flow Extension does NOT revoke this status.
    nonisolated var isCoreWorkCompleted: Bool {
        phase == .work && termination == .natural
    }
}
