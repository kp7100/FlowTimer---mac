# ADR 005: Statistics Dashboard Redesign (Sprint 1)

## Context
The initial `StatisticsView` was a simple, static list of stats without temporal filtering or graphical visualizations. To elevate FlowTimer to a premium macOS productivity utility, we required a complete dashboard redesign that follows Apple's Human Interface Guidelines, provides intuitive date navigation, shows focus distribution visually, and avoids anxious gamification patterns.

## Decision
We completely rewrote `StatisticsView.swift` from scratch:

1. **Information Hierarchy**: Structured the dashboard starting with a top segmented period control (Day, Week, Month, Year), followed by a Hero card (Total Focus Time & Daily Goal Progress), a Swift Chart for focus distribution, a Metric Grid for session/focus quality details, and a Tag progress list.
2. **Date Navigation**: Built a calendar-aware navigation header that dynamically shifts boundaries based on selected periods and prevents navigating into future dates with zero data.
3. **Hourly Focus Distribution & Ratio Clamping**: For the Day view, we implemented an algorithm that intersects the session's duration across the exact hour bins it spanned. We corrected a major bug where sleep/long paused sessions leaked false blocks to midnight hours by introducing an `activeRatio = record.duration / totalElapsed` scaling factor to ensure only actual active focus time is distributed.
4. **Adaptive Colors**: Configured all graphical elements (Swift Charts, progress capsules) to dynamically resolve to the user's native system Accent Color.
5. **Real-time Pause Tracking**: Added `pauseCount` tracking directly inside `TimerManager` and stored it on `SessionRecord`, enabling accurate calculation of "Pause Count" and "Average Pauses per Session" metrics.
6. **Reusable Modular Design**: Decomposed the dashboard into modular views: `StatisticsHeader`, `StatisticsHeroCard`, `StatisticsChartCard`, `StatisticsMetricGrid`, `StatisticCard`, `StatisticsTagsSection`, and `EmptyStatisticsView`.
7. **Canonical In-Memory Session Consolidation**: To ensure the menu bar paused title and the Statistics view show identical numbers in real-time, `StatisticsView` consolidates the active in-progress session record (`TimerManager.activeSessionRecord`) on-the-fly, inserting it dynamically into statistics calculation.
8. **Decoupled Windows**: Decoupled Statistics from Settings entirely. The Menu Bar popover exposes "Statistics" and "Settings" as separate actions, opening independent native `NSWindow` sheets instead of sharing a tab control.
9. **Polished Y-axis**: Implemented dynamic hour/minute scale formatting on Swift Charts Y-axis tick values.

## Consequences
- **Positive**: Clean, modern, Apple-style layout with spacious grid alignment and proper light/dark mode adaptation.
- **Positive**: Visual representation of optimal focus times via Swift Charts.
- **Positive**: Correct tracking of self-interruptions (pauses) per session.
- **Positive**: Perfect real-time data consistency across popovers, menu bars, and windows.
- **Positive**: Zero confusion about metric time scopes.

