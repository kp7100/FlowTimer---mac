import SwiftUI
import AppKit
import Foundation
import Observation
import Combine

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
    var hasTriggeredFlowTransition: Bool = false
    var flowTransitionID: UUID?
    
    // Recovery
    /// Fires once at wake for any surface currently subscribed. Surfaces opened
    /// after the event fires never receive it — PassthroughSubject has no memory.
    let recoveryEventPublisher = PassthroughSubject<RecoveryEvent, Never>()
    private var sleepTimestamp: Date? = nil
    
    var recentAdaptiveBreakPayload: AdaptiveBreakPayload?
    private var currentPhaseRemainingSeconds: Int = 0
    private var currentSessionPauseCount: Int = 0
    private var isTransitioningPhase: Bool = false

    // Cycle work tracking — used ONLY for Long Break eligibility and progress dots.
    // Completely independent of currentSession / completedSessions.
    private(set) var cycleAccumulatedWork: Int = 0  // seconds; Focus + Flow only
    private(set) var longBreakUnlocked: Bool = false
    // Shadow values used to detect settings changes that require a cycle reset.
    private var lastKnownWorkDuration: Int = 0
    private var lastKnownSessionsPerCycle: Int = 0
    private var lastKnownShortBreakDuration: Int = 0
    private var lastKnownLongBreakDuration: Int = 0
    
    // Gap-check tracking
    private var lastPausedAt: Date?
    private var lastSessionFragmentID: UUID?
    private var accumulatedDurationAtLastSplit: TimeInterval = 0
    private let sessionSplitThresholdSeconds: TimeInterval = 300 // 5 minutes
    
    var flowExtensionElapsedSeconds: Double {
        guard phase == .flowExtension else { return 0 }
        return Double(currentPhaseDuration)
    }

    /// Total work seconds that must accumulate before a Long Break is earned.
    var cycleTargetWorkDuration: Int {
        settings.workDuration * settings.sessionsPerCycle
    }

    /// Number of fully completed work segments in the current cycle.
    /// Clamped to [0, sessionsPerCycle] — can never overflow.
    var cycleCompletedSegments: Int {
        min(cycleAccumulatedWork / max(1, settings.workDuration), settings.sessionsPerCycle)
    }

    /// Live work seconds accumulated in the current phase that haven't been committed to cycleAccumulatedWork yet.
    var liveWorkSeconds: Int {
        if phase == .work {
            return max(0, settings.workDuration - currentPhaseRemainingSeconds)
        } else if phase == .flowExtension {
            return max(0, currentPhaseDuration)
        }
        return 0
    }

    /// Progress from 0.0 to 1.0 for the segment at the given index.
    func progress(forSegment index: Int) -> Double {
        let totalWork = Double(cycleAccumulatedWork + liveWorkSeconds)
        let target = Double(max(1, settings.workDuration))
        let milestoneStart = Double(index) * target
        
        if totalWork <= milestoneStart {
            return 0.0
        } else if totalWork >= milestoneStart + target {
            return 1.0
        } else {
            return (totalWork - milestoneStart) / target
        }
    }
    
    var canResetCycle: Bool {
        if state != .idle { return true }
        if phase != .work { return true }
        if currentSession != 1 { return true }
        if currentPhaseRemainingSeconds != settings.workDuration { return true }
        if accumulatedDurationAtLastSplit > 0 { return true }
        return false
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
        self.lastKnownWorkDuration = manager.settings.workDuration
        self.lastKnownSessionsPerCycle = manager.settings.sessionsPerCycle
        
        
        Task { [weak self] in
            await self?.initialize()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.sleepTimestamp == nil {
                    self.sleepTimestamp = Date()
                }
                self.pause()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.performRecoveryIfNeeded()
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
    
    func performRecoveryIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            guard let sleepTime = self.sleepTimestamp else { return }
            
            let now = Date()
            let elapsed = now.timeIntervalSince(sleepTime)
            self.sleepTimestamp = nil
            
            // Finalise any session fragment that spanned the pause gap
            if let pauseTime = self.lastPausedAt {
                await self.processPauseGap(pauseTime: pauseTime, resumeTime: now)
                self.lastPausedAt = nil
            }
            
            switch self.phase {
            case .work:
                // Focus: resume exactly where paused — no message needed
                break
                
            case .flowExtension:
                if elapsed <= 10.0 {
                    // Brief interruption — resume flow silently
                    await self.engine.resume()
                } else {
                    // Long interruption — end flow, cascade into break evaluation
                    await self.takeBreakAsync()
                    
                    let breakElapsed = elapsed - 10.0
                    let remaining = await self.engine.remainingSeconds
                    let elapsedInt = Int(breakElapsed)

                    if elapsedInt < remaining {
                        await self.engine.addElapsedSeconds(Double(elapsedInt))
                        await self.engine.resume()
                        self.recoveryEventPublisher.send(.breakResumed)
                    } else {
                        self.recoveryEventPublisher.send(.breakCompleted)
                        self.handlePhaseCompletion()
                    }
                }
                
            case .shortBreak, .longBreak:
                let remaining = await self.engine.remainingSeconds
                let elapsedInt = Int(elapsed)
                
                if elapsedInt < remaining {
                    await self.engine.addElapsedSeconds(Double(elapsedInt))
                    await self.engine.resume()
                    self.recoveryEventPublisher.send(.breakResumed)
                } else {
                    self.recoveryEventPublisher.send(.breakCompleted)
                    self.handlePhaseCompletion()
                }
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
                accumulatedDurationAtLastSplit: accumulatedDurationAtLastSplit,
                cycleAccumulatedWork: cycleAccumulatedWork,
                longBreakUnlocked: longBreakUnlocked
            )
            
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: "timerSnapshot")
            }
        }
    }
    
    func settingsDidChange() {
        Task { [weak self] in
            guard let self else { return }

            let workDurationChanged = self.settings.workDuration != self.lastKnownWorkDuration
            let sessionsChanged = self.settings.sessionsPerCycle != self.lastKnownSessionsPerCycle
            let shortBreakChanged = self.settings.shortBreakDuration != self.lastKnownShortBreakDuration
            let longBreakChanged = self.settings.longBreakDuration != self.lastKnownLongBreakDuration
            
            let durationOrCycleChanged = workDurationChanged || sessionsChanged || shortBreakChanged || longBreakChanged

            if durationOrCycleChanged {
                self.lastKnownWorkDuration = self.settings.workDuration
                self.lastKnownSessionsPerCycle = self.settings.sessionsPerCycle
                self.lastKnownShortBreakDuration = self.settings.shortBreakDuration
                self.lastKnownLongBreakDuration = self.settings.longBreakDuration
                
                // Completely reset the timer state using resetCycle which finalizes the session and resets the cycle
                self.resetCycle()
                
                // Ensure state returns to idle for a fresh session
                self.state = .idle
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
            self.cycleAccumulatedWork = snapshot.cycleAccumulatedWork
            self.longBreakUnlocked = snapshot.longBreakUnlocked
            self.lastKnownWorkDuration = settings.workDuration
            self.lastKnownSessionsPerCycle = settings.sessionsPerCycle
            
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
        guard !isTransitioningPhase else { return }
        isTransitioningPhase = true
        defer { isTransitioningPhase = false }
        
        lastPausedAt = nil
        lastSessionFragmentID = nil
        accumulatedDurationAtLastSplit = 0
        
        switch phase {
        case .work:
            if isSkip {
                if longBreakUnlocked {
                    cycleAccumulatedWork = 0
                    longBreakUnlocked = false
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

            if longBreakUnlocked {
                // Cycle target was reached — award the Long Break and reset the cycle.
                cycleAccumulatedWork = 0
                longBreakUnlocked = false
                currentPhaseDuration = settings.longBreakDuration
                self.currentPhaseRemainingSeconds = settings.longBreakDuration
                await engine.setPhase(.longBreak, direction: .countdown)
                await engine.setDuration(settings.longBreakDuration)
            } else {
                // Cycle target not yet reached — compute adaptive short break.
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
                        continuationOf: self.lastSessionFragmentID,
                        termination: .natural
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
                // Accumulate the completed Focus session toward the cycle target.
                self.cycleAccumulatedWork += self.settings.workDuration
                self.checkLongBreakUnlock()
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
    
    /// Async counterpart to takeBreak(), used by performRecoveryIfNeeded so the
    /// phase transition fully completes (via await) before recovery evaluates
    /// the resulting break state.
    private func takeBreakAsync() async {
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
                continuationOf: lastSessionFragmentID,
                termination: .natural
            )
            HistoryManager.shared.addSession(record)
        }

        self.currentPhaseStartDate = nil
        self.lastPausedAt = nil
        self.lastSessionFragmentID = nil
        self.accumulatedDurationAtLastSplit = 0

        // Accumulate the entire Flow session toward the cycle target.
        // engineSnapshot.accumulatedSeconds is the total engine time since Flow began.
        // This is read BEFORE advanceToNextPhase overwrites currentPhaseDuration.
        let totalFlowElapsed = Int(engineSnapshot.accumulatedSeconds.rounded())
        cycleAccumulatedWork += totalFlowElapsed
        checkLongBreakUnlock()

        NotificationManager.shared.sendNotification(
            title: "Flow Extension Complete",
            body: "Starting your break."
        )

        await self.advanceToNextPhase(isSkip: false)
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
                    continuationOf: lastSessionFragmentID,
                    termination: .natural
                )
                HistoryManager.shared.addSession(record)
            }

            self.currentPhaseStartDate = nil
            self.lastPausedAt = nil
            self.lastSessionFragmentID = nil
            self.accumulatedDurationAtLastSplit = 0

            // Accumulate the entire Flow session toward the cycle target.
            // engineSnapshot.accumulatedSeconds is the total engine time since Flow began.
            // This is read BEFORE advanceToNextPhase overwrites currentPhaseDuration.
            let totalFlowElapsed = Int(engineSnapshot.accumulatedSeconds.rounded())
            self.cycleAccumulatedWork += totalFlowElapsed
            self.checkLongBreakUnlock()

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
    
    private func finalizePartialSession(termination: SessionTermination, setContinuation: Bool, forcePauseTime: Date? = nil) async {
        guard phase == .work || phase == .flowExtension else { return }
        guard let phaseStart = currentPhaseStartDate else { return }
        
        let engineSnapshot = await engine.snapshot()
        let fragmentDuration = engineSnapshot.accumulatedSeconds - accumulatedDurationAtLastSplit
        
        if fragmentDuration > 0 {
            let currentID = UUID()
            let record = SessionRecord(
                id: currentID,
                phase: phase,
                startDate: phaseStart,
                endDate: forcePauseTime ?? Date(),
                duration: fragmentDuration,
                tag: currentTag,
                pauseCount: currentSessionPauseCount,
                continuationOf: lastSessionFragmentID,
                termination: termination
            )
            HistoryManager.shared.addSession(record)
            if setContinuation {
                lastSessionFragmentID = currentID
            } else {
                lastSessionFragmentID = nil
            }
        }
    }

    private func processPauseGap(pauseTime: Date, resumeTime: Date) async {
        guard phase == .work || phase == .flowExtension else { return }
        
        let gap = resumeTime.timeIntervalSince(pauseTime)
        guard gap >= sessionSplitThresholdSeconds else { return }
        
        await finalizePartialSession(termination: .split, setContinuation: true, forcePauseTime: pauseTime)
        
        // Begin the new segment
        currentPhaseStartDate = resumeTime
        accumulatedDurationAtLastSplit = (await engine.snapshot()).accumulatedSeconds
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
    
    func resetCycle() {
        Task { [weak self] in
            guard let self else { return }
            await self.engine.pause()

            // Finalize the partial session directly using real elapsed time
            await self.finalizePartialSession(termination: .reset, setContinuation: false, forcePauseTime: self.lastPausedAt)

            // Reset to cycle 1 completely
            self.currentSession = 1
            self.cycleAccumulatedWork = 0
            self.longBreakUnlocked = false
            self.phase = .work
            self.currentPhaseStartDate = nil
            self.currentPhaseDuration = settings.workDuration
            self.currentPhaseRemainingSeconds = settings.workDuration
            self.lastPausedAt = nil
            self.lastSessionFragmentID = nil
            self.accumulatedDurationAtLastSplit = 0
            self.currentSessionPauseCount = 0

            await engine.setPhase(.work, direction: .countdown)
            await engine.setDuration(settings.workDuration)
        }
    }

    /// Sets `longBreakUnlocked` when the cycle target is first reached.
    /// Called after every accumulation to `cycleAccumulatedWork`.
    /// Silent — no notification, no interruption, no UI change beyond the dots.
    private func checkLongBreakUnlock() {
        guard !longBreakUnlocked else { return }
        if cycleAccumulatedWork >= cycleTargetWorkDuration {
            longBreakUnlocked = true
        }
    }
}
