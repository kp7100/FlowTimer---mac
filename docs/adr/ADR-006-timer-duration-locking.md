# ADR 006: Timer Duration Locking and Settings Sync

## Context
When a user changes duration settings (e.g. Work Duration, Break Duration), there needs to be a strict deterministic rule on how those changes apply to the timer, especially when a session is already active. Previously, the system suffered from desync issues:
- Global settings were incorrectly used to calculate the elapsed time of active sessions, causing goal progress metrics to spike.
- A bug allowed saved snapshots of paused sessions to override the user's latest settings upon app restart, leading to sessions getting "stuck" on old durations.
- There was ambiguity around whether changing a setting mid-flight should dynamically resize the current running/paused session, or if it should only apply to the next session.

## Decision
We established a strict **Fixed-Length Session Lifecycle Rule**:
1. **Definition of "Started"**: A session is definitively "started" the moment the user presses Play for the first time (transitioning from `TimerState.idle` to `TimerState.running`).
2. **Session Lock**: Once a session has started (is `.running` or `.paused`), its target duration is permanently locked in for the remainder of its lifecycle. Changes to global duration settings are stored but will strictly be ignored by the current session.
3. **Idle Syncing**: If a session has *never* been started (`TimerState.idle`), it is considered fresh. Any changes to global duration settings while a session is `.idle` will immediately update the timer's target duration and the displayed remaining time.
4. **App Relaunch/Restore**: 
   - If the app was quit with an `.idle` session, upon restart, the timer forces a sync with the latest settings, overwriting any stale data in the snapshot.
   - If the app was quit with a `.running` or `.paused` session, upon restart, the timer restores with the original locked-in duration it had when it was started. It will ignore newer global settings.
5. **Phase Transitions**: When a session naturally completes and transitions to a new phase (e.g., break -> work), the state machine explicitly queries the newest settings to construct the fresh session, guaranteeing that new settings take effect immediately on the next session.

## Implementation Details
- `TimerState.idle` and `TimerState.paused` are structurally distinguished in `TimerEngine`. `.idle` is an absolute guarantee that the session has never been started.
- The `TimerManager` calculates elapsed time exclusively using its locked `currentPhaseDuration - currentPhaseRemainingSeconds` rather than the global `settings.workDuration`.
- `TimerManager` subscribes to a `timerSettingsDidChange` Notification to push live updates to `.idle` sessions.
- In `TimerManager.initialize()`, snapshot restorations conditionally update `TimerEngine`'s total duration based strictly on `snapshot.engineSnapshot.state == .idle`.

## Consequences
- **Positive**: Complete predictability for the user. A 25-minute Pomodoro will always be exactly 25 minutes once started.
- **Positive**: Eliminated desync bugs with Goal Progress metrics and persistent "stuck" durations across app restarts.
- **Negative**: Users who wish to extend an active session on the fly by changing global settings cannot do so; they must rely on Flow Extension or manually stop/reset the current session.
