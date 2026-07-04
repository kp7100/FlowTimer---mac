import Foundation

struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let phase: TimerPhase
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let tag: String?
}
