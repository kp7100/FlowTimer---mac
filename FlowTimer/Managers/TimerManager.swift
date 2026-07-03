import SwiftUI
import Observation

@MainActor
@Observable
final class TimerManager {
    private let engine: TimerEngine
    
    var settings = TimerSettings()
    
    var remainingTimeFormatted: String
    var isRunning: Bool = false
    var state: TimerState = .idle
    var phase: TimerPhase = .work
    
    var currentSession: Int = 1
    var totalSessions: Int { settings.totalSessions }
    
    var sessionTitle: String = "Session 1"
    
    var menuBarTitle: String {
        switch phase {
        case .work:
            return sessionTitle
        case .shortBreak:
            return "Break"
        case .longBreak:
            return "Long Break"
        case .flowExtension:
            return "Flow"
        }
    }
    
    init() {
        let defaultSettings = TimerSettings()
        self.settings = defaultSettings
        self.remainingTimeFormatted = TimeFormatter.format(seconds: defaultSettings.workDuration)
        self.engine = TimerEngine(durationInSeconds: defaultSettings.workDuration)
        setupEngine()
    }
    
    private func setupEngine() {
        Task {
            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
            
            await engine.setCallbacks(
                onTick: { [weak self] remainingSeconds in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.remainingTimeFormatted = TimeFormatter.format(seconds: remainingSeconds)
                    }
                },
                onStateChange: { [weak self] newState in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.state = newState
                        self.isRunning = (newState == .running)
                    }
                },
                onPhaseChange: { [weak self] newPhase in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.phase = newPhase
                    }
                },
                onCompleted: { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.handlePhaseCompletion()
                    }
                }
            )
        }
    }
    
    private func handlePhaseCompletion() {
        Task {
            switch phase {
            case .work:
                if currentSession >= totalSessions {
                    await engine.setPhase(.longBreak, direction: .countdown)
                    await engine.setDuration(settings.longBreakDuration)
                } else {
                    await engine.setPhase(.shortBreak, direction: .countdown)
                    await engine.setDuration(settings.shortBreakDuration)
                }
                await engine.start()
                
            case .shortBreak:
                currentSession += 1
                await engine.setPhase(.work, direction: .countdown)
                await engine.setDuration(settings.workDuration)
                await engine.start()
                
            case .longBreak:
                currentSession = 1
                await engine.setPhase(.work, direction: .countdown)
                await engine.setDuration(settings.workDuration)
                await engine.start()
                
            case .flowExtension:
                break
            }
        }
    }
    
    func start() {
        Task {
            await engine.start()
        }
    }
    
    func pause() {
        Task {
            await engine.pause()
        }
    }
    
    func resume() {
        Task {
            await engine.resume()
        }
    }
    
    func reset() {
        Task {
            currentSession = 1
            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
        }
    }
}
