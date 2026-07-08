import Foundation

struct WellnessContext: Equatable {
    let phaseID: Date          // TimerManager.currentPhaseStartDate
    let phase: TimerPhase      // To check if it's a short break or long break
    let currentSession: Int    // To check if it's the break before the final session
    let sessionsPerCycle: Int  // To determine the final session index
}
