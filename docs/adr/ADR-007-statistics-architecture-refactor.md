# ADR 007: Statistics Architecture Refactor

## Context
As FlowTimer's feature set expanded to include "Flow Extensions" and detailed statistics, the `StatisticsView` began to experience massive UI stutters. The root causes were:
1. **O(N) Render Cycles:** The UI was calculating statistics by iterating over the entire raw history array dynamically on every render cycle.
2. **Main Thread File I/O:** Every completed session forced a synchronous JSON encoding and atomic disk write on the `@MainActor`.
3. **Complex Fragment Merging:** Flow Extensions were stored as separate `SessionRecord` fragments in history but needed to be merged with their parent `.work` phases at display time, causing redundant calculations.

## Decision
We completely decoupled the statistics presentation layer from the raw storage layer by implementing a robust caching and background-processing pipeline:

### 1. `ContinuousSessionBuilder` (The Logic Actor)
- A dedicated Swift `actor` that operates in the background.
- It receives a value-copy of the raw `[SessionRecord]` array and merges contiguous fragments (e.g., Work + Flow Extension) into unified `ContinuousSession` models using the `continuationOf` UUID relationship.
- It calculates which specific dates were affected by new records, avoiding unnecessary full-history rebuilds.

### 2. `StatisticsStore` (The Presentation Cache)
- An `@Observable @MainActor` class that acts as the UI's data source.
- It maintains a `[Date: DailySummary]` dictionary. Each `DailySummary` pre-computes that day's total focus time, pause count, and completed sessions.
- When `StatisticsView` needs to display stats for a Week/Month/Year, it simply requests `getStats(for: DateInterval)` which aggregates the pre-computed `DailySummary` objects in O(D) time (where D = days in the interval), completely eliminating O(N) rendering.

### 3. `HistoryPersister` (The File I/O Actor)
- A dedicated Swift `actor` strictly responsible for file writes.
- `HistoryManager` now passes value-copies of the history array to the persister.
- The persister uses structured concurrency (`Task.detached`) to perform JSON encoding and disk writing off the main thread.
- **Write Coalescing:** If multiple saves are requested rapidly, the actor overwrites its `pendingSnapshot` and performs a single background write, completely eliminating overlapping disk I/O.

## Consequences
- **Positive:** UI rendering in the Statistics window is now instantly responsive (O(1) to lookup a day, O(D) to lookup a month), regardless of history size.
- **Positive:** Completing a timer no longer stutters the main thread, as the O(N) disk write was moved to `HistoryPersister`.
- **Positive:** Separation of concerns. `HistoryManager` handles raw storage, the builder handles business logic, and the store handles caching.
- **Negative / Technical Debt:** The builder's incremental cache logic currently relies on checking if `records.count > processedCount`. If historical records are ever edited, deleted, or imported without changing the array size, the cache will become stale. A more robust `historyRevision` tracking mechanism will be required if historical mutations are added.
