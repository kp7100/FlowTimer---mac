import Foundation

@available(macOS 13.0, *)
actor TimerEngine {
    private(set) var onTick: (@Sendable (Int) -> Void)?
    private(set) var onStateChange: (@Sendable (TimerState) -> Void)?
    private(set) var onPhaseChange: (@Sendable (TimerPhase) -> Void)?
    private(set) var onCompleted: (@Sendable () -> Void)?
    
    func setCallbacks(
        onTick: (@Sendable (Int) -> Void)? = nil,
        onStateChange: (@Sendable (TimerState) -> Void)? = nil,
        onPhaseChange: (@Sendable (TimerPhase) -> Void)? = nil,
        onCompleted: (@Sendable () -> Void)? = nil
    ) {
        if let onTick { self.onTick = onTick }
        if let onStateChange { self.onStateChange = onStateChange }
        if let onPhaseChange { self.onPhaseChange = onPhaseChange }
        if let onCompleted { self.onCompleted = onCompleted }
    }
    
    private(set) var state: TimerState = .idle {
        didSet {
            onStateChange?(state)
        }
    }
    
    private(set) var phase: TimerPhase = .work {
        didSet {
            onPhaseChange?(phase)
        }
    }
    
    private(set) var direction: TimerDirection = .countdown
    private(set) var totalSeconds: Int
    
    var remainingSeconds: Int {
        return displayedSeconds
    }
    
    var elapsedSeconds: Int {
        return totalSeconds - remainingSeconds
    }
    
    // Core Engine State
    private let clock = SuspendingClock()
    private var targetDuration: Duration
    private var accumulatedDuration: Duration = .zero
    private var runningSince: SuspendingClock.Instant?
    
    private var task: Task<Void, Never>?
    private let tickInterval = Duration.milliseconds(100)
    private var lastPublishedSecond: Int?
    
    init(durationInSeconds: Int) {
        self.totalSeconds = durationInSeconds
        self.targetDuration = .seconds(durationInSeconds)
    }
    
    deinit {
        task?.cancel()
    }
    
    func setPhase(_ newPhase: TimerPhase, direction: TimerDirection = .countdown) {
        self.phase = newPhase
        self.direction = direction
    }
    
    func setDuration(_ seconds: Int) {
        task?.cancel()
        task = nil
        
        self.totalSeconds = seconds
        self.targetDuration = .seconds(seconds)
        self.accumulatedDuration = .zero
        self.runningSince = nil
        self.lastPublishedSecond = nil
        self.state = .idle
        
        publishTick()
    }
    
    func start() {
        guard state == .idle || state == .paused else { return }
        state = .running
        runningSince = clock.now
        publishTick()
        startLoop()
    }
    
    func resume() {
        start()
    }
    
    func pause() {
        guard state == .running else { return }
        task?.cancel()
        task = nil
        
        if let start = runningSince {
            accumulatedDuration += clock.now - start
        }
        runningSince = nil
        state = .paused
        publishTick() // Final sync
    }
    
    func reset() {
        task?.cancel()
        task = nil
        accumulatedDuration = .zero
        runningSince = nil
        lastPublishedSecond = nil
        state = .idle
        publishTick()
    }
    
    // MARK: - Core Logic
    
    var totalElapsed: Duration {
        if let start = runningSince {
            return accumulatedDuration + (clock.now - start)
        }
        return accumulatedDuration
    }
    
    private var displayedSeconds: Int {
        let elapsed = totalElapsed
        let remaining = targetDuration - elapsed
        
        if direction == .countdown {
            let s = remaining.components.seconds
            let a = remaining.components.attoseconds
            let doubleRemaining = Double(s) + Double(a) / 1e18
            return Int(ceil(doubleRemaining))
        } else {
            let s = elapsed.components.seconds
            let a = elapsed.components.attoseconds
            let doubleElapsed = Double(s) + Double(a) / 1e18
            return Int(floor(doubleElapsed))
        }
    }
    
    private func publishTick() {
        let current = displayedSeconds
        
        if direction == .countdown && totalElapsed >= targetDuration {
            if lastPublishedSecond != 0 {
                lastPublishedSecond = 0
                onTick?(0)
            }
        } else {
            if current != lastPublishedSecond {
                lastPublishedSecond = current
                onTick?(current)
            }
        }
    }
    
    private func startLoop() {
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                // Check completion BEFORE sleeping
                if direction == .countdown && totalElapsed >= targetDuration {
                    state = .completed
                    
                    if lastPublishedSecond != 0 {
                        lastPublishedSecond = 0
                        onTick?(0)
                    }
                    
                    onCompleted?()
                    break
                }
                
                publishTick()
                
                do {
                    try await clock.sleep(for: tickInterval)
                } catch {
                    break
                }
            }
        }
    }
}
