import Foundation

enum WellnessMessageType {
    case wellness
    case progress
    case adaptiveBreak
}

struct WellnessMessage: Equatable {
    let text: String
    let type: WellnessMessageType
}
