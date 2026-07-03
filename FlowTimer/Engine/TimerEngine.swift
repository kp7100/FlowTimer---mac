import Foundation

enum TimerState: Sendable, Equatable {
    case idle
    case running
    case paused
    case completed
}

enum TimerPhase: Sendable, Equatable {
    case work
    case shortBreak
    case longBreak
    case flowExtension
}

enum TimerDirection: Sendable, Equatable {
    case countdown
    case countup
}

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
            let newState = state
            if let callback = onStateChange {
                Task { @MainActor in
                    callback(newState)
                }
            }
        }
    }
    
    private(set) var phase: TimerPhase = .work {
        didSet {
            let newPhase = phase
            if let callback = onPhaseChange {
                Task { @MainActor in
                    callback(newPhase)
                }
            }
        }
    }
    
    private(set) var direction: TimerDirection = .countdown
    
    private(set) var remainingSeconds: Int
    private let totalSeconds: Int
    
    var elapsedSeconds: Int {
        totalSeconds - remainingSeconds
    }
    
    private var task: Task<Void, Never>?
    private let clock = ContinuousClock()
    private let tickInterval = Duration.seconds(1)
    
    init(durationInSeconds: Int) {
        self.totalSeconds = durationInSeconds
        self.remainingSeconds = durationInSeconds
    }
    
    deinit {
        task?.cancel()
    }
    
    func setPhase(_ newPhase: TimerPhase, direction: TimerDirection = .countdown) {
        self.phase = newPhase
        self.direction = direction
    }
    
    func start() {
        guard state == .idle || state == .paused else { return }
        state = .running
        
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                if direction == .countdown && remainingSeconds <= 0 {
                    state = .completed
                    if let callback = onCompleted {
                        Task { @MainActor in
                            callback()
                        }
                    }
                    break
                }
                
                do {
                    try await clock.sleep(for: tickInterval)
                    if Task.isCancelled { break }
                    
                    if direction == .countdown {
                        remainingSeconds -= 1
                    } else {
                        remainingSeconds += 1 // count up mode
                    }
                    
                    let currentSeconds = remainingSeconds
                    if let callback = onTick {
                        Task { @MainActor in
                            callback(currentSeconds)
                        }
                    }
                    
                    if direction == .countdown && remainingSeconds <= 0 {
                        state = .completed
                        if let callback = onCompleted {
                            Task { @MainActor in
                                callback()
                            }
                        }
                        break
                    }
                } catch {
                    break
                }
            }
        }
    }
    
    func resume() {
        start()
    }
    
    func pause() {
        guard state == .running else { return }
        task?.cancel()
        task = nil
        state = .paused
    }
    
    func reset() {
        task?.cancel()
        task = nil
        remainingSeconds = totalSeconds
        state = .idle
        
        let currentSeconds = remainingSeconds
        if let callback = onTick {
            Task { @MainActor in
                callback(currentSeconds)
            }
        }
    }
}
