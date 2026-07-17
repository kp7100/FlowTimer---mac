# ADR 008: Session Termination Semantics & Reset Cycle

## Context
With the introduction of the **Reset Cycle** feature (allowing users to abort a work session and restart from Cycle 1 while still recording their elapsed focus time), we uncovered a critical flaw in how the statistics engine inferred completed sessions.

Previously, `ContinuousSessionBuilder` inferred completion purely from the *existence* of a root-level `.work` or `.flowExtension` record in the history array. If a record existed and wasn't a continuation of something else, it was wrapped in a `ContinuousSession` and counted as a "Completed Session" by `StatisticsStore`.

This architecture failed in several scenarios:
1. **Reset Cycle:** An aborted session saves its elapsed time to history. It has no continuation, so it was falsely counted as a completed session.
2. **Flow Extensions:** Since Flow Extensions have no target duration, a naturally completed extension (user clicked "Take Break") was mathematically indistinguishable from an aborted extension (user clicked "Reset Cycle") purely from timestamps.
3. **Abandoned Pause-Gaps:** If a user paused a timer (creating a pause-gap split fragment) and then force quit the app, the split fragment was left in history. Upon relaunch, it was falsely inferred as completed because it lacked a continuation.

## Decision
We moved completion semantics explicitly into the persistence model by introducing the `SessionTermination` enum to `SessionRecord`. 

A `SessionRecord` now acts as a pure historical fragment that definitively records *how* it ended:

```swift
enum SessionTermination: String, Codable, Hashable {
    case natural
    case reset
    case split
}
```

### 1. Unified Partial Finalization
`TimerManager` now channels all partial and terminal record generation through a single helper: `finalizePartialSession(termination:setContinuation:)`.

### 2. Termination Rules
- **Natural Completion (Timer hits 0):** `termination = .natural`
- **Flow Extension (Take Break):** `termination = .natural`
- **Reset Cycle:** `termination = .reset`
- **Pause-Gap Split:** `termination = .split` (the fragment was interrupted, but the logical chain continues)

### 3. Builder Inference
`ContinuousSessionBuilder` now derives the logical completion of a full `ContinuousSession` chain by inspecting the `termination` reason of its **final** constituent fragment. 
- If the final fragment is `.natural`, the session counts as completed.
- If the final fragment is `.reset` or `.split` (e.g. stranded by a crash), the logical session is considered aborted/uncompleted and is correctly excluded from the `completedSessions` metric in `StatisticsStore`.

## Consequences
- **Positive:** Accuracy of "Completed Sessions" is guaranteed, immune to app crashes or feature expansions (like Reset Cycle).
- **Positive:** The data model is explicit. We no longer rely on brittle chronological inferences to determine user intent.
- **Backward Compatibility:** Older records in `FlowTimerHistory.json` missing the `termination` key will default to `.natural` when decoded via the `ContinuousSessionBuilder` fallback, safely preserving historical completion metrics.
