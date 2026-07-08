import Foundation

enum WellnessMessageType {
    case wellness
    case progress
}

struct WellnessMessage: Equatable {
    let text: String
    let type: WellnessMessageType
}
