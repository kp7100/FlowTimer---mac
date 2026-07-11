# ADR 004: Flow Extension Limit and Removal of Auto Start Breaks

## Context
Flow Extension was designed to be open-ended, allowing users to extend their focus session indefinitely. However, to prevent users from over-working without realizing it, we need a configurable maximum cap—a "Flow Extension Limit"—where the app automatically transitions to a break phase after a set period of overtime.

Additionally, our audit of the "Auto Start Breaks" setting (`autoStartBreaks`) confirmed that because entering a break was historically triggered only by manual user actions (clicking "Take Break" or "Skip Phase"), gating the break's auto-start was unnecessary. Since there was no automatic entry point into Break, the toggle had no real programmatic value, making it redundant.

## Decision
1. **Flow Extension Limit**: Added a user-configurable limit (`flowExtensionLimit` in minutes) to `TimerSettings`. By default, this is set to `nil` (unlimited) to preserve the existing user experience. When configured (e.g. 15, 30, 45, 60 minutes), the `onTick` callback in `TimerManager` monitors the elapsed count-up. Once reached, it invokes the centralized `takeBreak()` routine.
2. **Centralized Action**: Reuse the existing `takeBreak()` / Flow → Break transition path instead of introducing secondary transition implementations.
3. **Deprecate Auto Start Breaks**: Removed `autoStartBreaks` completely from settings, the UI panel, and manager transition gates, as it is obsolete. Breaks are now always started automatically upon transition (which matches native expectations).
4. **Auto Start Work**: Retained the separate "Auto Start Focus Sessions Automatically" (`autoStartWork`) setting, as it remains programmatic and meaningful.

## Consequences
- **Positive**: Simplified Settings UI by removing a redundant toggle and introducing a highly requested productivity cap.
- **Positive**: Centralized transition logic prevents duplication of history-logging and adaptive break calculations.
- **Positive**: Backwards-compatibility is preserved for existing users via a `nil` default.
