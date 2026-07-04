import SwiftUI
import Observation

@MainActor
@Observable
final class TimerManager {
    private let engine: TimerEngine
    
    private var settingsManager: SettingsManager
    
    var settings: TimerSettings { settingsManager.settings }
    
    var remainingTimeFormatted: String
    var isRunning: Bool = false
    var state: TimerState = .idle
    var phase: TimerPhase = .work
    var currentSession: Int = 1
    var totalSessions: Int { settings.sessionsPerCycle }
    
    var currentTag: String? {
        guard let id = settings.selectedTagId,
              let tag = TagManager.shared.tags.first(where: { $0.id == id }) else { return nil }
        return tag.name
    }
    
    var activeTag: String? { currentPhaseTagName }
    private var currentPhaseTagName: String?
    
    private var currentPhaseStartDate: Date?
    private var currentPhaseDuration: Int
    
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
    
    init(settingsManager: SettingsManager = .shared) {
        self.settingsManager = settingsManager
        self.currentPhaseDuration = settingsManager.settings.workDuration
        self.remainingTimeFormatted = TimeFormatter.format(seconds: settingsManager.settings.workDuration)
        self.engine = TimerEngine(durationInSeconds: settingsManager.settings.workDuration)
        
        let initialTagId = settingsManager.settings.selectedTagId
        if let id = initialTagId, let tag = TagManager.shared.tags.first(where: { $0.id == id }) {
            self.currentPhaseTagName = tag.name
        } else {
            self.currentPhaseTagName = nil
        }
        
        setupEngine()
    }
    
    func settingsDidChange() {
        if state == .idle {
            Task {
                let duration: Int
                switch phase {
                case .work: duration = settings.workDuration
                case .shortBreak: duration = settings.shortBreakDuration
                case .longBreak: duration = settings.longBreakDuration
                case .flowExtension: duration = settings.workDuration
                }
                self.currentPhaseDuration = duration
                await engine.setDuration(duration)
                self.remainingTimeFormatted = TimeFormatter.format(seconds: duration)
            }
        }
    }
    
    private func setupEngine() {
        Task {
            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
            
            await engine.setCallbacks(
                onTick: { [weak self] remainingSeconds in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if self.phase == .flowExtension {
                            self.currentPhaseDuration = remainingSeconds
                            self.remainingTimeFormatted = "+\(TimeFormatter.format(seconds: remainingSeconds))"
                        } else {
                            self.remainingTimeFormatted = TimeFormatter.format(seconds: remainingSeconds)
                        }
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
        if let startDate = currentPhaseStartDate {
            let record = SessionRecord(
                id: UUID(),
                phase: phase,
                startDate: startDate,
                endDate: Date(),
                duration: TimeInterval(currentPhaseDuration),
                tag: (phase == .work || phase == .flowExtension) ? currentPhaseTagName : nil
            )
            HistoryManager.shared.addSession(record)
        }
        currentPhaseStartDate = nil
        
        Task {
            switch phase {
            case .work:
                NotificationManager.shared.sendNotification(
                    title: "Work Session Complete",
                    body: "Flow Extension started.\nTake a break whenever you're ready."
                )
                
                currentPhaseStartDate = Date()
                currentPhaseDuration = 0
                await engine.setPhase(.flowExtension, direction: .countup)
                await engine.setDuration(0)
                await engine.start()
                
            case .shortBreak, .longBreak:
                NotificationManager.shared.sendNotification(title: "Break Complete", body: "Ready for another focus session.")
                if phase == .shortBreak {
                    currentSession += 1
                } else {
                    currentSession = 1
                }
                currentPhaseTagName = self.currentTag
                currentPhaseDuration = settings.workDuration
                await engine.setPhase(.work, direction: .countdown)
                await engine.setDuration(settings.workDuration)
                
                if settings.autoStartWork {
                    self.start()
                }
                
            case .flowExtension:
                break
            }
        }
    }
    
    func takeBreak() {
        Task {
            await engine.pause()
            
            if let startDate = currentPhaseStartDate {
                let record = SessionRecord(
                    id: UUID(),
                    phase: .flowExtension,
                    startDate: startDate,
                    endDate: Date(),
                    duration: TimeInterval(currentPhaseDuration),
                    tag: currentPhaseTagName
                )
                HistoryManager.shared.addSession(record)
            }
            currentPhaseStartDate = nil
            
            NotificationManager.shared.sendNotification(
                title: "Flow Extension Complete",
                body: "Starting your break."
            )
            
            if currentSession >= totalSessions {
                currentPhaseDuration = settings.longBreakDuration
                await engine.setPhase(.longBreak, direction: .countdown)
                await engine.setDuration(settings.longBreakDuration)
            } else {
                currentPhaseDuration = settings.shortBreakDuration
                await engine.setPhase(.shortBreak, direction: .countdown)
                await engine.setDuration(settings.shortBreakDuration)
            }
            
            if settings.autoStartBreaks {
                self.start()
            }
        }
    }
    
    func start() {
        if currentPhaseStartDate == nil {
            currentPhaseStartDate = Date()
        }
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
            currentPhaseStartDate = nil
            currentPhaseTagName = self.currentTag
            currentPhaseDuration = settings.workDuration
            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
        }
    }
}
