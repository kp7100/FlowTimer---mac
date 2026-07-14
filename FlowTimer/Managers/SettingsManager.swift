import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()
    
    var settings: TimerSettings {
        didSet {
            save()
            if oldValue.launchAtLogin != settings.launchAtLogin {
                syncLaunchAtLogin()
            }
            NotificationCenter.default.post(name: Notification.Name("timerSettingsDidChange"), object: nil)
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
        
        Task { @MainActor in
            self.syncLaunchAtLogin()
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
    
    private func syncLaunchAtLogin() {
        do {
            if settings.launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Launch at login sync failed: \(error.localizedDescription)")
        }
    }
}
