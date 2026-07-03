import Foundation

enum TimerState: Sendable {
    case idle
    case running
    case paused
    case completed
}

extension TimerState: Equatable {
    nonisolated static func == (lhs: TimerState, rhs: TimerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.running, .running), (.paused, .paused), (.completed, .completed): return true
        default: return false
        }
    }
}

enum TimerPhase: Sendable {
    case work
    case shortBreak
    case longBreak
    case flowExtension
}

extension TimerPhase: Equatable {
    nonisolated static func == (lhs: TimerPhase, rhs: TimerPhase) -> Bool {
        switch (lhs, rhs) {
        case (.work, .work), (.shortBreak, .shortBreak), (.longBreak, .longBreak), (.flowExtension, .flowExtension): return true
        default: return false
        }
    }
}

enum TimerDirection: Sendable {
    case countdown
    case countup
}

extension TimerDirection: Equatable {
    nonisolated static func == (lhs: TimerDirection, rhs: TimerDirection) -> Bool {
        switch (lhs, rhs) {
        case (.countdown, .countdown), (.countup, .countup): return true
        default: return false
        }
    }
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
            onStateChange?(state)
        }
    }
    
    private(set) var phase: TimerPhase = .work {
        didSet {
            onPhaseChange?(phase)
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
                    onCompleted?()
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
                    
                    onTick?(remainingSeconds)
                    
                    if direction == .countdown && remainingSeconds <= 0 {
                        state = .completed
                        onCompleted?()
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
        onTick?(remainingSeconds)
    }
}
