import SwiftUI
import Observation

@MainActor
@Observable
final class TimerManager {
    private let engine: TimerEngine
    
    var remainingTimeFormatted: String = "25:00"
    var isRunning: Bool = false
    var state: TimerState = .idle
    var phase: TimerPhase = .work
    
    init() {
        self.engine = TimerEngine(durationInSeconds: 25 * 60)
        setupEngine()
    }
    
    private func setupEngine() {
        Task {
            await engine.setPhase(.work, direction: .countdown)
            
            await engine.setCallbacks(
                onTick: { [weak self] remainingSeconds in
                    Task { @MainActor in
                        self?.remainingTimeFormatted = TimeFormatter.format(seconds: remainingSeconds)
                    }
                },
                onStateChange: { [weak self] newState in
                    Task { @MainActor in
                        self?.state = newState
                        self?.isRunning = (newState == .running)
                    }
                },
                onPhaseChange: { [weak self] newPhase in
                    Task { @MainActor in
                        self?.phase = newPhase
                    }
                },
                onCompleted: { [weak self] in
                    Task { @MainActor in
                        // Handle completion logic here later
                    }
                }
            )
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
            await engine.reset()
        }
    }
}
