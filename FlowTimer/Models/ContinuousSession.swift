import Foundation

struct ContinuousSession: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let pauseCount: Int
    let tag: String?
    let isCompleted: Bool
    let constituentRecords: [SessionRecord] // Raw records that make up this session
}
