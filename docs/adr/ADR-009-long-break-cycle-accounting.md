# ADR 009: Long Break Eligibility & Cycle Accounting

## Context

FlowTimer previously gated Long Breaks on a completed-session count
(`currentSession >= totalSessions`). This was replaced with an
accumulated-work-duration model:

- `cycleAccumulatedWork` tracks Focus + Flow seconds earned this cycle.
- `longBreakUnlocked` is set when `cycleAccumulatedWork >= cycleTargetWorkDuration`.
- Long Break eligibility is gated on `longBreakUnlocked`, never on `currentSession`.

The migration introduced two behaviours that look like bugs but are intentional.
Both have been audited and verified. This ADR records the decisions so they are
not accidentally reverted.

---

## Decision 1 — Session splits do not affect cycle accounting

### Background

During a Flow Extension the user may pause for longer than the session-split
threshold (5 minutes). When that happens, `processPauseGap` calls
`finalizePartialSession`, which writes a history fragment to `HistoryManager`
and advances `accumulatedDurationAtLastSplit` to the current engine total.

This is a history-layer concern only.

### What `accumulatedDurationAtLastSplit` is for

Its sole purpose is to allow `fragmentDuration` to be computed for each
non-overlapping history record:

```
fragmentDuration = engine.accumulatedSeconds - accumulatedDurationAtLastSplit
```

Each fragment gets a precise, non-overlapping duration in the history file.

### What it is NOT for

It has no role in `cycleAccumulatedWork`. Neither `finalizePartialSession` nor
`processPauseGap` touches the engine's internal `accumulatedDuration`. The
engine continues accumulating from the moment `start()` was called with
`setDuration(0)` at the beginning of Flow.

### Why `cycleAccumulatedWork += engineSnapshot.accumulatedSeconds` is correct

`engineSnapshot.accumulatedSeconds` returns `totalElapsed`, which is the
cumulative running time since the engine was last reset via `setDuration()`.
`setDuration()` is called exactly once at the start of Flow
(`advanceToNextPhase(.work, isSkip: false)` → `engine.setDuration(0)`).
It is not called by `finalizePartialSession` or `processPauseGap`.

Concrete trace (workDuration = 25 min):

```
Flow starts            engine.accumulatedDuration = 0
                       accumulatedDurationAtLastSplit = 0

Work 20 min            engine.accumulatedDuration = 1200 s

Pause >5 min (split)
  finalizePartialSession:
    fragmentDuration = 1200 - 0 = 1200 s → history record ✅
    accumulatedDurationAtLastSplit = 1200

Resume and work 10 min engine.accumulatedDuration = 1800 s

takeBreak():
  fragmentDuration = 1800 - 1200 = 600 s → history record ✅
  totalFlowElapsed = Int(1800) = 1800 s
  cycleAccumulatedWork += 1800 ✅  (= 30 min = 20 + 10, correct)
```

The two history records (1200 s and 600 s) together cover the full 30 minutes
without overlap. `cycleAccumulatedWork` receives the same 30 minutes from the
engine total. No double-counting occurs.

### Ruling

Correct by design. Do not attempt to subtract `accumulatedDurationAtLastSplit`
from `engineSnapshot.accumulatedSeconds` when computing `cycleAccumulatedWork`.
That would produce an undercount equal to the pre-split work time.

---

## Decision 2 — Skipping Flow forfeits Long Break progress

### Behaviour

`skipCurrentPhase()` during Flow Extension:

1. Pauses the engine.
2. Sets `currentPhaseStartDate = nil` (no history record written).
3. Calls `advanceToNextPhase(isSkip: true)`.

Inside `advanceToNextPhase`, the `.flowExtension` case does not inspect
`isSkip`. It reads `currentPhaseDuration` to compute the adaptive short break,
then starts the break. `cycleAccumulatedWork` is **not** incremented.

The user receives a correctly-sized break proportional to elapsed Flow time,
but that Flow time is not credited toward Long Break eligibility.

### Why this is intentional

The product rule established during the Long Break eligibility design:

> Only naturally completed work earns Long Break credit.

"Naturally completed" for Flow Extension means the user clicked "Take Break."
Skip is the deliberate abandonment of the current phase. It is consistent with
how skipping a Focus session works — skipped sessions also contribute zero
credit (they do not call `checkLongBreakUnlock`).

This is also consistent with ADR-008 (Session Termination Semantics):

- **Take Break → Flow ends** → `termination = .natural` → work is credited.
- **Skip** → `currentPhaseStartDate = nil` → no record written → no credit.

The skip chevron is "I want a break now, cancel what I was doing." The "Take
Break" button is "I have chosen to stop Flow and commit this work."

### Ruling

Expected behaviour. Do not add cycle accumulation to `skipCurrentPhase()`.

If this decision is ever reconsidered (e.g., "skip should still credit partial
work"), update this ADR and add `cycleAccumulatedWork += currentPhaseDuration`
and `checkLongBreakUnlock()` before the `advanceToNextPhase` call in
`skipCurrentPhase()`. Also decide whether a history record with
`termination = .natural` should be written at that point.

---

## Related

- ADR-008: Session Termination Semantics (defines `.natural` vs `.reset` vs `.split`)
- `docs/long-break-cycle-redesign.md` — full feature specification, state model, and dot behaviour
- `docs/statistics-caching-architecture.md` (cycle dot display, `cycleDisplayedSegments`)
- `TimerManager.swift` — `takeBreak()`, `takeBreakAsync()`, `skipCurrentPhase()`,
  `advanceToNextPhase()`, `checkLongBreakUnlock()`
