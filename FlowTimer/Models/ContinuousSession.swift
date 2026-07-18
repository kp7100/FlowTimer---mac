import Foundation

/// Represents a Logical Focus Session.
///
/// A Logical Focus Session begins when a Work phase starts.
/// Flow Extension is considered part of the same Logical Focus Session.
///
/// This model intentionally tracks two independent concepts:
/// - `duration`: The summed total duration of all constituent fragments (e.g. 25m Work + 18m Flow = 43m).
/// - `coreWorkCompleted`: Evaluates to true if *any* constituent fragment achieved its target naturally.
///
/// The legacy `isCompleted` concept was removed because it conflated "Did the timer finish naturally?"
/// with "Is this the final fragment in the timeline chunk?".
///
/// Duration-based statistics operate on this merged session.
/// Stopping or resetting a Flow Extension must never revoke a completed Work phase.
struct ContinuousSession: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let pauseCount: Int
    let tag: String?
    let coreWorkCompleted: Bool
    let constituentRecords: [SessionRecord] // Raw records that make up this session
}
