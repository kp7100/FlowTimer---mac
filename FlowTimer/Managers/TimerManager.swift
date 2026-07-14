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
    private var currentPhaseRemainingSeconds: Int = 0
    private var currentSessionPauseCount: Int = 0
    
    // Gap-check tracking
    private var lastPausedAt: Date?
    private var lastSessionFragmentID: UUID?
    private var accumulatedDurationAtLastSplit: TimeInterval = 0
    private let sessionSplitThresholdSeconds: TimeInterval = 300 // 5 minutes
    
    var flowExtensionElapsedSeconds: Double {
        guard phase == .flowExtension else { return 0 }
        return Double(currentPhaseDuration)
    }
    
    var activeSessionRecord: SessionRecord? {
        guard let startDate = currentPhaseStartDate else { return nil }
        guard phase == .work || phase == .flowExtension else { return nil }
        
        let elapsed: TimeInterval
        if phase == .work {
            elapsed = TimeInterval(max(0, currentPhaseDuration - currentPhaseRemainingSeconds))
        } else {
            elapsed = TimeInterval(max(0, currentPhaseDuration))
        }
        
        return SessionRecord(
            id: phaseInstanceID,
            phase: phase,
            startDate: startDate,
            endDate: Date(),
            duration: elapsed,
            tag: currentTag,
            pauseCount: currentSessionPauseCount
        )
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
    
    private func formatProgressDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((seconds / 60.0).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(totalMinutes)m"
        }
    }
    
    var menuBarTitle: String {
        switch phase {
        case .shortBreak:
            return "Short Break"
        case .longBreak:
            return "Long Break"
        case .work, .flowExtension:
            if state == .paused {
                let completedWorkToday = HistoryManager.shared.focusTimeToday()
                let completedFlowToday = HistoryManager.shared.flowExtensionToday()
                let completedToday = completedWorkToday + completedFlowToday
                
                let currentElapsed: TimeInterval
                if phase == .work {
                    currentElapsed = TimeInterval(max(0, currentPhaseDuration - currentPhaseRemainingSeconds))
                } else {
                    currentElapsed = TimeInterval(max(0, currentPhaseDuration))
                }
                
                let totalTodaySeconds = completedToday + currentElapsed
                
                if settings.goalsEnabled {
                    let target = settings.goalFocusTime
                    let completed = totalTodaySeconds >= target
                    let completedText = TimeFormatter.formatForStats(seconds: totalTodaySeconds)
                    let goalText = TimeFormatter.formatForStats(seconds: target)
                    return completed ? "\(completedText) / \(goalText) ✓" : "\(completedText) / \(goalText)"
                } else {
                    let focusedText = TimeFormatter.formatForStats(seconds: totalTodaySeconds)
                    return "Focused \(focusedText)"
                }
            } else {
                return sessionTitle
            }
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
        self.currentPhaseRemainingSeconds = manager.settings.workDuration
        self.remainingTimeFormatted = TimeFormatter.format(seconds: manager.settings.workDuration)
        self.engine = TimerEngine(durationInSeconds: manager.settings.workDuration)
        
        
        Task { [weak self] in
            await self?.initialize()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWake()
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
                self?.saveState()
            }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("timerSettingsDidChange"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.settingsDidChange()
            }
        }
    }
    
    private func handleWake() {
        Task { [weak self] in
            guard let self else { return }
            if let pauseTime = self.lastPausedAt {
                let now = Date()
                await self.processPauseGap(pauseTime: pauseTime, resumeTime: now)
                self.lastPausedAt = now
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
                sessionTitle: customSessionTitle,
                lastPausedAt: lastPausedAt,
                lastSessionFragmentID: lastSessionFragmentID,
                accumulatedDurationAtLastSplit: accumulatedDurationAtLastSplit
            )
            
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: "timerSnapshot")
            }
        }
    }
    
    func settingsDidChange() {
        Task { [weak self] in
            guard let self else { return }
            
            // Only apply settings to the current session if it hasn't started yet.
            guard self.state == .idle else { return }
            
            let duration: Int
            switch self.phase {
            case .work: duration = self.settings.workDuration
            case .shortBreak: duration = self.settings.shortBreakDuration
            case .longBreak: duration = self.settings.longBreakDuration
            case .flowExtension: duration = self.settings.workDuration
            }
            
            if duration != self.currentPhaseDuration {
                await self.engine.updateDuration(duration)
                let newRemaining = await self.engine.remainingSeconds
                self.currentPhaseDuration = await self.engine.totalSeconds
                self.currentPhaseRemainingSeconds = newRemaining
                self.remainingTimeFormatted = TimeFormatter.format(seconds: newRemaining)
                self.saveState()
            }
        }
    }
    
    private func initialize() async {
        
        await engine.setCallbacks(
            onTick: { [weak self] remainingSeconds in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.currentPhaseRemainingSeconds = remainingSeconds
                    
                    if self.phase == .work && remainingSeconds == 1 && !self.hasTriggeredFlowTransition {
                        self.hasTriggeredFlowTransition = true
                        self.flowTransitionID = UUID()
                    }
                    
                    if self.phase == .flowExtension {
                        self.currentPhaseDuration = remainingSeconds
                        let displaySeconds = self.settingsManager.settings.workDuration + remainingSeconds
                        self.remainingTimeFormatted = "\(TimeFormatter.format(seconds: displaySeconds))"
                        
                        if let limitSeconds = self.settings.flowExtensionLimit {
                            if remainingSeconds >= limitSeconds {
                                self.takeBreak()
                            }
                        }
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
            self.lastPausedAt = snapshot.lastPausedAt
            self.lastSessionFragmentID = snapshot.lastSessionFragmentID
            self.accumulatedDurationAtLastSplit = snapshot.accumulatedDurationAtLastSplit ?? 0
            
            await engine.restore(from: snapshot.engineSnapshot)
            
            let currentSettingDuration: Int
            switch self.phase {
            case .work: currentSettingDuration = settings.workDuration
            case .shortBreak: currentSettingDuration = settings.shortBreakDuration
            case .longBreak: currentSettingDuration = settings.longBreakDuration
            case .flowExtension: currentSettingDuration = settings.workDuration
            }
            
            // Only update the restored session's duration if it hasn't actually started yet
            if snapshot.engineSnapshot.state == .idle && currentSettingDuration != snapshot.engineSnapshot.totalSeconds {
                await engine.updateDuration(currentSettingDuration)
            }
            
            self.currentPhaseDuration = await engine.totalSeconds
            self.currentPhaseRemainingSeconds = await engine.remainingSeconds
            self.remainingTimeFormatted = TimeFormatter.format(seconds: self.currentPhaseRemainingSeconds)
            
            if let pauseTime = self.lastPausedAt {
                let now = Date()
                await self.processPauseGap(pauseTime: pauseTime, resumeTime: now)
                self.lastPausedAt = now
            }
        } else {
            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
            self.currentPhaseRemainingSeconds = settings.workDuration
        }
        
        await engine.publishCurrentState()
    }
    
    private func advanceToNextPhase(isSkip: Bool = false) async {
        lastPausedAt = nil
        lastSessionFragmentID = nil
        accumulatedDurationAtLastSplit = 0
        
        switch phase {
        case .work:
            if isSkip {
                if currentSession >= totalSessions {
                    currentPhaseDuration = settings.longBreakDuration
                    self.currentPhaseRemainingSeconds = settings.longBreakDuration
                    await engine.setPhase(.longBreak, direction: .countdown)
                    await engine.setDuration(settings.longBreakDuration)
                } else {
                    currentPhaseDuration = settings.shortBreakDuration
                    self.currentPhaseRemainingSeconds = settings.shortBreakDuration
                    await engine.setPhase(.shortBreak, direction: .countdown)
                    await engine.setDuration(settings.shortBreakDuration)
                }
                self.start()
            } else {
                currentPhaseStartDate = Date()
                currentPhaseDuration = 0
                self.currentPhaseRemainingSeconds = 0
                self.currentSessionPauseCount = 0
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
            self.currentPhaseRemainingSeconds = settings.workDuration
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
                self.currentPhaseRemainingSeconds = configuredBreakDuration
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
                self.currentPhaseRemainingSeconds = adaptiveBreakDuration
                await engine.setPhase(.shortBreak, direction: .countdown)
                await engine.setDuration(adaptiveBreakDuration)
            }
            self.start()
        }
    }
    
    private func handlePhaseCompletion() {
        Task { [weak self] in
            guard let self else { return }
            let engineSnapshot = await engine.snapshot()
            
            if let startDate = self.currentPhaseStartDate {
                let fragmentDuration = engineSnapshot.accumulatedSeconds - self.accumulatedDurationAtLastSplit
                let isFocusPhase = (self.phase == .work || self.phase == .flowExtension)
                let finalDuration = isFocusPhase ? fragmentDuration : TimeInterval(self.currentPhaseDuration)
                
                if finalDuration > 0 {
                    let record = SessionRecord(
                        id: UUID(),
                        phase: self.phase,
                        startDate: startDate,
                        endDate: Date(),
                        duration: finalDuration,
                        tag: isFocusPhase ? self.currentTag : nil,
                        pauseCount: self.currentSessionPauseCount,
                        continuationOf: self.lastSessionFragmentID
                    )
                    HistoryManager.shared.addSession(record)
                }
            }
            
            self.currentPhaseStartDate = nil
            self.lastPausedAt = nil
            self.lastSessionFragmentID = nil
            self.accumulatedDurationAtLastSplit = 0
            
            switch self.phase {
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
            
            await self.advanceToNextPhase(isSkip: false)
        }
    }
    
    func takeBreak() {
        Task { [weak self] in
            guard let self else { return }
            await engine.pause()
            
            if let pauseTime = self.lastPausedAt {
                await self.processPauseGap(pauseTime: pauseTime, resumeTime: Date())
            }
            
            let engineSnapshot = await engine.snapshot()
            let fragmentDuration = engineSnapshot.accumulatedSeconds - self.accumulatedDurationAtLastSplit
            
            if let startDate = currentPhaseStartDate, fragmentDuration > 0 {
                let record = SessionRecord(
                    id: UUID(),
                    phase: .flowExtension,
                    startDate: startDate,
                    endDate: Date(),
                    duration: fragmentDuration,
                    tag: currentTag,
                    pauseCount: currentSessionPauseCount,
                    continuationOf: lastSessionFragmentID
                )
                HistoryManager.shared.addSession(record)
            }
            
            self.currentPhaseStartDate = nil
            self.lastPausedAt = nil
            self.lastSessionFragmentID = nil
            self.accumulatedDurationAtLastSplit = 0
            
            NotificationManager.shared.sendNotification(
                title: "Flow Extension Complete",
                body: "Starting your break."
            )
            
            await self.advanceToNextPhase(isSkip: false)
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
            currentSessionPauseCount = 0
        }
        Task { [weak self] in
            await self?.engine.start()
        }
    }
    
    private func processPauseGap(pauseTime: Date, resumeTime: Date) async {
        guard phase == .work || phase == .flowExtension else { return }
        guard let phaseStart = currentPhaseStartDate else { return }
        
        let gap = resumeTime.timeIntervalSince(pauseTime)
        guard gap >= sessionSplitThresholdSeconds else { return }
        
        let engineSnapshot = await engine.snapshot()
        let fragmentDuration = engineSnapshot.accumulatedSeconds - accumulatedDurationAtLastSplit
        
        if fragmentDuration > 0 {
            let currentID = UUID()
            let record = SessionRecord(
                id: currentID,
                phase: phase,
                startDate: phaseStart,
                endDate: pauseTime,
                duration: fragmentDuration,
                tag: currentTag,
                pauseCount: currentSessionPauseCount,
                continuationOf: lastSessionFragmentID
            )
            HistoryManager.shared.addSession(record)
            lastSessionFragmentID = currentID
        }
        
        // Begin the new segment
        currentPhaseStartDate = resumeTime
        accumulatedDurationAtLastSplit = engineSnapshot.accumulatedSeconds
        currentSessionPauseCount = 0
    }
    func pause() {
        if state == .running {
            currentSessionPauseCount += 1
            if lastPausedAt == nil {
                lastPausedAt = Date()
            }
        }
        Task { [weak self] in
            await self?.engine.pause()
        }
    }
    
    func resume() {
        Task { [weak self] in
            guard let self else { return }
            if let pauseTime = self.lastPausedAt {
                await self.processPauseGap(pauseTime: pauseTime, resumeTime: Date())
                self.lastPausedAt = nil
            }
            await self.engine.resume()
        }
    }
    
    func reset() {
        Task { [weak self] in
            guard let self else { return }
            currentSession = 1
            currentPhaseStartDate = nil
            currentPhaseDuration = settings.workDuration
            self.currentPhaseRemainingSeconds = settings.workDuration
            self.lastPausedAt = nil
            self.lastSessionFragmentID = nil
            self.accumulatedDurationAtLastSplit = 0
            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
        }
    }
}
