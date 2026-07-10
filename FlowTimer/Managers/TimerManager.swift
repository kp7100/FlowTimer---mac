import SwiftUI
import AppKit
import Observation

enum FlowWellnessState {
    case coffee
    case stretch
    case water
    case eyes
    case walk
}

struct AdaptiveBreakPayload: Equatable {
    let totalWorkMinutes: Int
    let extraBreakMinutes: Int
}

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
    var phaseInstanceID: UUID = UUID()
    var flowTransitionID: UUID?
    var recentAdaptiveBreakPayload: AdaptiveBreakPayload?
    private var hasTriggeredFlowTransition = false
    
    var flowExtensionElapsedSeconds: Double {
        guard phase == .flowExtension else { return 0 }
        return Double(currentPhaseDuration)
    }
    
    var currentSession: Int = 1
    var totalSessions: Int { settings.sessionsPerCycle }
    
    var currentTag: String? {
        guard let id = settings.selectedTagId,
              let tag = TagManager.shared.tags.first(where: { $0.id == id }) else { return nil }
        return tag.name
    }
    

    
    private var currentPhaseStartDate: Date?
    var phaseStartDate: Date { currentPhaseStartDate ?? Date() }
    private var currentPhaseDuration: Int
    private var lastCheckpoint: Date = Date()
    
    var customSessionTitle: String? {
        didSet {
            let trimmed = customSessionTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed?.isEmpty == true {
                customSessionTitle = nil
            } else if customSessionTitle != trimmed {
                customSessionTitle = trimmed
            }
            saveState()
        }
    }
    
    var sessionTitle: String {
        return customSessionTitle ?? "Session \(currentSession)"
    }
    
    var menuBarTitle: String {
        switch phase {
        case .work:
            return sessionTitle
        case .shortBreak:
            return "Short Break"
        case .longBreak:
            return "Long Break"
        case .flowExtension:
            return "Flow"
        }
    }
    
        private let flowWellnessIconThresholdSeconds: Int = 900
    
    var flowWellnessState: FlowWellnessState {
        guard phase == .flowExtension else { return .coffee }
        if currentPhaseDuration >= flowWellnessIconThresholdSeconds {
            return .stretch
        }
        return .coffee
    }
    
    init(settingsManager: SettingsManager? = nil) {
        let manager = settingsManager ?? .shared
        self.settingsManager = manager
        self.currentPhaseDuration = manager.settings.workDuration
        self.remainingTimeFormatted = TimeFormatter.format(seconds: manager.settings.workDuration)
        self.engine = TimerEngine(durationInSeconds: manager.settings.workDuration)
        
        
        Task { [weak self] in
            await self?.initialize()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pause()
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pause()
                self?.saveState()
            }
        }
    }
    
    func saveState() {
        Task { [weak self] in
            guard let self else { return }
            let engineSnapshot = await engine.snapshot()
            let snapshot = TimerSnapshot(
                currentSession: currentSession,
                currentPhaseStartDate: currentPhaseStartDate,
                engineSnapshot: engineSnapshot,
                sessionTitle: customSessionTitle
            )
            
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: "timerSnapshot")
            }
        }
    }
    
    func settingsDidChange() {
        if state == .idle {
            Task { [weak self] in
                guard let self else { return }
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
    
    private func initialize() async {
        
        await engine.setCallbacks(
            onTick: { [weak self] remainingSeconds in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    
                    if self.phase == .work && remainingSeconds == 1 && !self.hasTriggeredFlowTransition {
                        self.hasTriggeredFlowTransition = true
                        self.flowTransitionID = UUID()
                    }
                    
                    if self.phase == .flowExtension {
                        self.currentPhaseDuration = remainingSeconds
                        let displaySeconds = self.settingsManager.settings.workDuration + remainingSeconds
                        self.remainingTimeFormatted = "\(TimeFormatter.format(seconds: displaySeconds))"
                    } else {
                        self.remainingTimeFormatted = TimeFormatter.format(seconds: remainingSeconds)
                    }
                    
                    if Date.now.timeIntervalSince(self.lastCheckpoint) >= 10 {
                        self.lastCheckpoint = Date.now
                        self.saveState()
                    }
                }
            },
            onStateChange: { [weak self] newState in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.state = newState
                    self.isRunning = (newState == .running)
                    self.saveState()
                }
            },
            onPhaseChange: { [weak self] newPhase in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.phase = newPhase
                    self.phaseInstanceID = UUID()
                    self.saveState()
                }
            },
            onCompleted: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.handlePhaseCompletion()
                }
            }
        )
        
        var shouldRestore = false
        var snapshotToRestore: TimerSnapshot?
        
        if let data = UserDefaults.standard.data(forKey: "timerSnapshot"),
           let snapshot = try? JSONDecoder().decode(TimerSnapshot.self, from: data) {
            
            let isToday = Calendar.current.isDateInToday(snapshot.engineSnapshot.savedAt)
            if isToday {
                shouldRestore = true
                snapshotToRestore = snapshot
            } else {
                UserDefaults.standard.removeObject(forKey: "timerSnapshot")
            }
        }
        
        if shouldRestore, let snapshot = snapshotToRestore {
            self.currentSession = snapshot.currentSession
            self.currentPhaseStartDate = snapshot.currentPhaseStartDate
            if let savedTitle = snapshot.sessionTitle {
                self.customSessionTitle = savedTitle
            } else {
                self.customSessionTitle = nil
            }
            await engine.restore(from: snapshot.engineSnapshot)
        } else {
            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
        }
        
        await engine.publishCurrentState()
    }
    
    private func advanceToNextPhase(isSkip: Bool = false) async {
        switch phase {
        case .work:
            if isSkip {
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
            } else {
                currentPhaseStartDate = Date()
                currentPhaseDuration = 0
                hasTriggeredFlowTransition = false
                await engine.setPhase(.flowExtension, direction: .countup)
                await engine.setDuration(0)
                await engine.start()
            }
            
        case .shortBreak, .longBreak:
            if phase == .shortBreak {
                currentSession += 1
            } else {
                currentSession = 1
            }
            currentPhaseDuration = settings.workDuration
            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
            
            if settings.autoStartWork {
                self.start()
            }
            
        case .flowExtension:
            let configuredWorkDuration = max(1, settings.workDuration) // Prevent division by zero
            let flowExtensionDuration = max(0, currentPhaseDuration)
            let totalWorkTime = configuredWorkDuration + flowExtensionDuration
            
            if currentSession >= totalSessions {
                let configuredBreakDuration = settings.longBreakDuration
                
                currentPhaseDuration = configuredBreakDuration
                await engine.setPhase(.longBreak, direction: .countdown)
                await engine.setDuration(configuredBreakDuration)
            } else {
                let configuredBreakDuration = settings.shortBreakDuration
                let exactAdaptiveBreakDuration = Double(totalWorkTime) * Double(configuredBreakDuration) / Double(configuredWorkDuration)
                let roundedMinutes = (exactAdaptiveBreakDuration / 60.0).rounded()
                let adaptiveBreakDuration = Int(roundedMinutes * 60.0)
                
                let extraBreakSeconds = adaptiveBreakDuration - configuredBreakDuration
                if extraBreakSeconds >= 60 {
                    let totalWorkMins = Int((Double(totalWorkTime) / 60.0).rounded())
                    let extraBreakMins = Int((Double(extraBreakSeconds) / 60.0).rounded())
                    self.recentAdaptiveBreakPayload = AdaptiveBreakPayload(totalWorkMinutes: totalWorkMins, extraBreakMinutes: extraBreakMins)
                } else {
                    self.recentAdaptiveBreakPayload = nil
                }
                
                currentPhaseDuration = adaptiveBreakDuration
                await engine.setPhase(.shortBreak, direction: .countdown)
                await engine.setDuration(adaptiveBreakDuration)
            }
            if settings.autoStartBreaks {
                self.start()
            }
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
                tag: (phase == .work || phase == .flowExtension) ? currentTag : nil
            )
            HistoryManager.shared.addSession(record)
        }
        currentPhaseStartDate = nil
        
        Task { [weak self] in
            guard let self else { return }
            switch phase {
            case .work:
                NotificationManager.shared.sendNotification(
                    title: "Work Session Complete",
                    body: "Flow Extension started.\nTake a break whenever you're ready."
                )
            case .shortBreak, .longBreak:
                NotificationManager.shared.sendNotification(title: "Break Complete", body: "Ready for another focus session.")
            case .flowExtension:
                break
            }
            
            await advanceToNextPhase(isSkip: false)
        }
    }
    
    func takeBreak() {
        Task { [weak self] in
            guard let self else { return }
            await engine.pause()
            
            if let startDate = currentPhaseStartDate {
                let record = SessionRecord(
                    id: UUID(),
                    phase: .flowExtension,
                    startDate: startDate,
                    endDate: Date(),
                    duration: TimeInterval(currentPhaseDuration),
                    tag: currentTag
                )
                HistoryManager.shared.addSession(record)
            }
            currentPhaseStartDate = nil
            
            NotificationManager.shared.sendNotification(
                title: "Flow Extension Complete",
                body: "Starting your break."
            )
            
            await advanceToNextPhase(isSkip: false)
        }
    }
    
    func skipCurrentPhase() {
        Task { [weak self] in
            guard let self else { return }
            await engine.pause()
            currentPhaseStartDate = nil
            await advanceToNextPhase(isSkip: true)
        }
    }
    
    func toggleTimer() {
        switch state {
        case .idle: start()
        case .running: pause()
        case .paused: resume()
        case .completed: break
        }
    }
    
    func start() {
        if currentPhaseStartDate == nil {
            currentPhaseStartDate = Date()
        }
        Task { [weak self] in
            await self?.engine.start()
        }
    }
    
    func pause() {
        Task { [weak self] in
            await self?.engine.pause()
        }
    }
    
    func resume() {
        Task { [weak self] in
            await self?.engine.resume()
        }
    }
    
    func reset() {
        Task { [weak self] in
            guard let self else { return }
            currentSession = 1
            currentPhaseStartDate = nil
            currentPhaseDuration = settings.workDuration
            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
        }
    }
}
