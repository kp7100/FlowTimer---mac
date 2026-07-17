# Long Break Cycle Redesign (Work-Based Progress)

## Overview

The Long Break system has been redesigned from a session-count model to a
work-duration model.

Previously, a user earned a Long Break after completing a fixed number of Focus
sessions.

Now, a Long Break is earned after accumulating a target amount of productive
work, regardless of how that work is distributed between Focus and Flow
Extension.

This better represents actual effort and removes inconsistencies where long Flow
sessions contributed nothing toward Long Break eligibility.

---

## Previous Behaviour

Cycle progress was based on `completedSessions`.

Example — Work 25 min, 4 sessions per cycle:

```
25 min Focus
+ 90 min Flow
= 1 / 4 sessions
```

Even though the user completed almost two hours of productive work, they were
still only one session closer to a Long Break. Flow Extension time did not
contribute. This made the cycle represent "number of Focus completions" rather
than "amount of work performed."

---

## New Behaviour

Cycle progress is now based on accumulated work duration. Every second of
productive work contributes toward the cycle. Both Focus and naturally completed
Flow Extension sessions count.

The target is:

```
cycleTargetWorkDuration = workDuration × sessionsPerCycle
```

Example — Work Duration 25 min, Sessions Per Cycle 4:

```
Target Work = 100 min
```

Any combination that reaches 100 minutes unlocks the Long Break:

```
25 + 25 + 25 + 25   ✓
25 + 75             ✓
40 + 60             ✓
15 + 20 + 65        ✓
```

---

## Cycle State

### Persistent state

```swift
private(set) var cycleAccumulatedWork: Int   // seconds; Focus + Flow only
private(set) var longBreakUnlocked: Bool
```

`cycleAccumulatedWork` is the committed source of truth for Long Break
eligibility. It is persisted in `TimerSnapshot` and survives app restarts.

### Computed targets

```swift
var cycleTargetWorkDuration: Int {
    settings.workDuration * settings.sessionsPerCycle
}

// Fully-completed segments — basis for Long Break gating
var cycleCompletedSegments: Int {
    min(cycleAccumulatedWork / max(1, settings.workDuration), settings.sessionsPerCycle)
}
```

### Display-only state (never persisted)

```swift
var cycleDisplayedSegments: Int {
    let liveFlowWork = phase == .flowExtension ? currentPhaseDuration : 0
    return min((cycleAccumulatedWork + liveFlowWork) / max(1, settings.workDuration),
               settings.sessionsPerCycle)
}
```

---

## Long Break Unlock

The previous session-count check:

```swift
// OLD
if currentSession >= totalSessions { ... }
```

is replaced with:

```swift
// NEW
if longBreakUnlocked { ... }
```

`longBreakUnlocked` is set silently (no notification, no interruption) by
`checkLongBreakUnlock()` after every work accumulation:

```swift
private func checkLongBreakUnlock() {
    guard !longBreakUnlocked else { return }
    if cycleAccumulatedWork >= cycleTargetWorkDuration {
        longBreakUnlocked = true
    }
}
```

---

## What Counts Toward the Cycle

### Focus completion

A Focus session that runs to zero naturally contributes:

```
cycleAccumulatedWork += settings.workDuration
```

Called in `handlePhaseCompletion()` for the `.work` case, before
`advanceToNextPhase`.

### Flow Extension (Take Break)

When the user clicks **Take Break** (or the flow limit triggers), the entire
engine-accumulated Flow duration contributes:

```
cycleAccumulatedWork += Int(engineSnapshot.accumulatedSeconds.rounded())
```

Called in both `takeBreak()` and `takeBreakAsync()`, after the history record
is written and before `advanceToNextPhase`.

Example:

```
25 min Focus  →  +25 min
18 min Flow   →  +18 min
─────────────────────────
43 min credited
```

### What does NOT count

| Action | Credit |
|---|---|
| Skip Focus | 0 |
| Skip Flow Extension | 0 |
| Reset Cycle | 0 |
| App crash / force-quit mid-session | 0 |

Only naturally completed productive work advances the cycle. See ADR-009 for
the verified rationale for each of these exclusions.

---

## Live Progress Display

A display-only property (`cycleDisplayedSegments`) was introduced so the
progress dots advance in real time during Flow Extension rather than waiting
until the user ends Flow.

### During Focus or idle

```
cycleDisplayedSegments == cycleCompletedSegments
```

Behaviour is identical to before.

### During Flow Extension

```
cycleDisplayedSegments =
    (cycleAccumulatedWork + currentPhaseDuration) / workDuration
```

`currentPhaseDuration` is the live countup elapsed time updated each tick by
the engine. The value of `cycleDisplayedSegments` only changes when it crosses
an integer segment boundary — it does not produce a continuous fractional fill.

`cycleAccumulatedWork` is not written during Flow. It is committed only when
Flow ends.

---

## Progress Dot Behaviour

Dots are **not** a live progress bar. The half-filled dot (◐) means "currently
working toward this segment" — it does not represent proportional progress.
State changes only at segment boundaries.

Example — Work Duration 30 s, Sessions 3:

| Event | Dots |
|---|---|
| Focus starts | ◐ ○ ○ |
| First Focus completes | ● ◐ ○ |
| Flow begins | ● ◐ ○ (unchanged until boundary) |
| Flow reaches +30 s | ● ● ◐ |
| Flow reaches +30 s | ● ● ● |

When all dots fill during Flow, Flow continues uninterrupted. The dots simply
stay at `● ● ●`. `longBreakUnlocked` is already `true` and will take effect
when the user ends Flow.

### Guard against overflow

`cycleDisplayedSegments` is clamped to `[0, sessionsPerCycle]`. A half-filled
dot never appears beyond the last index:

```swift
if index == completed && isActive && completed < timerManager.totalSessions {
    return .half
}
```

---

## Cycle Reset

The cycle resets `cycleAccumulatedWork = 0` and `longBreakUnlocked = false` in
four situations:

| Trigger | Code location |
|---|---|
| Long Break begins | `advanceToNextPhase(.flowExtension)` and `advanceToNextPhase(.work, isSkip:)` |
| `workDuration` changes | `settingsDidChange()` |
| `sessionsPerCycle` changes | `settingsDidChange()` |
| `resetCycle()` is called | `resetCycle()` |

Settings changes are detected by comparing `settings.workDuration` and
`settings.sessionsPerCycle` against shadow values (`lastKnownWorkDuration`,
`lastKnownSessionsPerCycle`). The reset fires regardless of timer state — it
does not wait for the timer to be idle.

---

## Persistence

Serialized in `TimerSnapshot`:

```swift
var cycleAccumulatedWork: Int = 0    // default 0 — old snapshots decode safely
var longBreakUnlocked: Bool = false  // default false — old snapshots decode safely
```

`cycleDisplayedSegments` is a computed property with no stored backing. It is
never serialized.

After a restore during Flow Extension:

1. `cycleAccumulatedWork` is restored from the snapshot (committed work only).
2. The engine restores `accumulatedSeconds` (the full Flow elapsed time).
3. `currentPhaseDuration` is set from `engine.totalSeconds`.
4. `cycleDisplayedSegments` immediately reflects committed + live work.

---

## Verified Design Decisions

These two behaviours look like bugs but are intentional. Both have been
formally audited. Full traces are in ADR-009.

### Session splits do not affect cycle accounting

Pause-gap splits write non-overlapping history fragments using
`accumulatedDurationAtLastSplit`. The engine's `accumulatedDuration` is never
reset by a split. `takeBreak()` reads `engineSnapshot.accumulatedSeconds`
(the cumulative engine total) to credit the full Flow work — not a
per-fragment value. Subtracting `accumulatedDurationAtLastSplit` would produce
an undercount.

### Skipping Flow forfeits Long Break progress

`skipCurrentPhase()` during Flow does not call `checkLongBreakUnlock()`. The
user receives an adaptive break proportional to elapsed Flow time, but that
time is not committed toward the cycle. This is intentional — skip is session
abandonment, not natural completion. Only "Take Break" commits Flow work.

---

## What Is Not Changed

| System | Status |
|---|---|
| `currentSession` / `completedSessions` | Unchanged — still tracked separately |
| Adaptive break calculation | Unchanged — still based on total work time |
| Statistics / history recording | Unchanged |
| Recovery system | Unchanged |
| `totalSessions` / `sessionsPerCycle` setting | Unchanged |

---

## Architecture Flow

```
Focus Completion
      │
      ▼
cycleAccumulatedWork += workDuration
checkLongBreakUnlock()
      │
      ▼
(or) Take Break during Flow
      │
      ▼
cycleAccumulatedWork += engine.accumulatedSeconds
checkLongBreakUnlock()
      │
      ┌──── longBreakUnlocked? ────┐
      │ NO                         │ YES
      ▼                            ▼
Short Break               Next work completion
(adaptive)                       │
                                 ▼
                           Long Break begins
                                 │
                                 ▼
                    cycleAccumulatedWork = 0
                    longBreakUnlocked = false
```

---

## Related Documents

- `docs/adr/ADR-009-long-break-cycle-accounting.md` — formal decision record with execution traces
- `docs/statistics-caching-architecture.md` — Statistics rendering and caching
- `TimerManager.swift` — implementation: `cycleAccumulatedWork`, `longBreakUnlocked`,
  `cycleDisplayedSegments`, `checkLongBreakUnlock()`, `takeBreak()`, `takeBreakAsync()`,
  `advanceToNextPhase()`, `settingsDidChange()`, `resetCycle()`
- `SessionProgressView.swift` — dot display using `cycleDisplayedSegments`
- `TimerSnapshot.swift` — persistence fields
