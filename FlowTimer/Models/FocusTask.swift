import Foundation

struct FocusTask: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var isCompleted: Bool
    var order: Int
    var focusDay: String
    var tagName: String?
    var completedAt: Date?
}
