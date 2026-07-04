import Foundation
import Observation

@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()
    
    var settings: TimerSettings {
        didSet {
            save()
        }
    }
    
    private let defaultsKey = "FlowTimerSettings"
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(TimerSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = TimerSettings()
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
}
