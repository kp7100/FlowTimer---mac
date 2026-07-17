# Statistics Performance Optimization & Caching Architecture

## Overview

Following the introduction of ADR-007 (Statistics Architecture Refactor), the Statistics feature already avoided expensive O(N) history scans during rendering by relying on `StatisticsStore.dailySummaries`.

A subsequent optimization pass focused on eliminating remaining render-time recomputation while preserving identical UI behavior and statistics.

The end result is a layered architecture where expensive computations are performed only when their inputs change, while SwiftUI bodies remain lightweight and read cached derived data.

---

## Motivation

Although ADR-007 solved the largest bottleneck, profiling revealed several remaining sources of unnecessary work.

These included:

- rebuilding `PeriodStats` during every render
- regenerating chart datasets every body evaluation
- rebuilding goal consistency data every body evaluation
- duplicate synchronization tasks
- render-time diagnostic logging
- unstable chart identities
- redundant scans across `dailySummaries`

Most importantly, the optimization pass later exposed an Observation render loop that required architectural changes to how caches were stored.

---

## Optimization Goals

The optimization focused on:

- keeping Statistics rendering deterministic
- eliminating repeated derived computations
- preserving identical statistics
- avoiding unnecessary SwiftUI invalidations
- maintaining simple cache invalidation rules

The architecture intentionally avoids:

- background chart processing
- multi-level memoization
- Combine pipelines
- complex cache hierarchies

---

## 1. PeriodStats Cache

### Previous behavior

Every Statistics render rebuilt an entirely new `PeriodStats`.

Even when nothing had changed, the following work repeated:

- aggregating daily summaries
- collecting focus records
- sorting records
- computing tag totals
- computing comparison values
- rebuilding hero metrics

Although the underlying data already existed inside `dailySummaries`, the final presentation model was recreated repeatedly.

### Current behavior

`StatisticsStore` now caches the computed `PeriodStats`.

The cache invalidates only when one of the inputs affecting the final result changes.

**Cache inputs**

- statistics revision
- selected period
- selected date
- comparison interval
- goal focus duration
- current-day boundary (for period calculations)
- active session (only when relevant)

If none of these inputs change, the cached `PeriodStats` is reused.

---

## 2. Chart Dataset Cache

Previously every chart regenerated its dataset during body evaluation.

Examples:

- hourly distribution
- weekday distribution
- monthly distribution
- yearly distribution

Even though the chart output was identical.

The chart pipeline now generates chart data once and caches it.

Charts simply render cached points.

### Stable chart identities

Originally chart points generated fresh UUIDs.

Every rebuild therefore appeared to SwiftUI as an entirely new dataset.

The optimization replaces generated UUIDs with stable identifiers derived from:

- bucket date
- bucket index
- hour index

This allows Swift Charts to diff efficiently instead of rebuilding everything.

---

## 3. Goal Consistency Cache

Goal consistency previously grouped records every render.

For Week and Month views this required:

- calendar normalization
- grouping records
- daily duration calculations

The grouped daily durations are now cached.

The Goal Consistency view simply consumes the prepared data.

---

## 4. Single Render Snapshot

`StatisticsView` now computes expensive derived values once during a render pass.

Instead of each child view independently requesting statistics, the parent prepares:

- interval
- active session
- PeriodStats
- chart dataset
- goal consistency data

These immutable values are then passed down the view hierarchy.

This mirrors the optimization previously applied to Today's Focus.

---

## 5. Reduced Synchronization

Previously multiple `.task` modifiers could trigger synchronization.

Examples included:

- initial appearance
- selected date
- selected period
- history revision

Only history changes actually require rebuilding Statistics.

Synchronization now follows history revision only.

Changing the displayed interval no longer triggers unnecessary synchronization work.

---

## 6. Single DailySummary Scan

The previous implementation scanned `dailySummaries` separately for:

- current period
- comparison period

The optimization combines these into a single traversal.

This reduces unnecessary iteration while preserving behavior.

---

## 7. Removed Render-Time Diagnostics

Diagnostic logging previously occurred during statistics generation.

Render-time file I/O has been completely removed from the Statistics rendering path.

Rendering now performs no synchronous disk access.

---

## Observation Render Loop Fix

### Problem

The initial cache implementation introduced an infinite render loop.

Caches were stored as regular stored properties inside the `@Observable` `StatisticsStore`.

During `StatisticsView.body`:

```
body
↓
cache lookup
↓
cache miss
↓
cache write           ← mutates @Observable property
↓
Observation publishes ← SwiftUI invalidates the view
↓
body
↓
cache miss            ← Date() in key has advanced; new key never matches
↓
...
```

The loop became infinite because cache keys contained the active session's `endDate`, which used `Date()`.

Since `Date()` changes continuously, every render generated a different cache key.
Every lookup was therefore a cache miss.
Every miss wrote to an observable property.
Every write invalidated the view.

The result was:

- 100% CPU usage
- frozen Statistics window
- infinite SwiftUI invalidation

Week, Month, and Year views were affected and Day was not because the active session was only considered relevant when the current interval contained the session's `endDate`. For longer periods, the active session was always included, continuously shifting the cache key.

---

### Solution

#### `@ObservationIgnored` caches

Implementation caches are not presentation state.

The following caches are marked with `@ObservationIgnored`:

```swift
@ObservationIgnored private var cachedPeriodStats: CachedPeriodStats?
@ObservationIgnored private var cachedChartData: CachedChartData?
@ObservationIgnored private var cachedGoalData: CachedGoalData?
```

Updating these caches no longer invalidates SwiftUI.

---

#### Stable active session cache key

Instead of using the mutable `SessionRecord` (whose `endDate` uses `Date()`) directly in the cache key, caching relies on a dedicated immutable snapshot type.

The snapshot contains only values that actually affect rendered output:

- session ID
- phase
- start date
- whole-second end-date bucket (truncated, not live `Date()`)
- whole-second duration
- tag
- pause count

Sub-second `Date()` drift no longer invalidates caches.
The cache updates only when visible statistics actually change.

---

## Cache Invalidation Rules

### PeriodStats cache

Invalidates when:

- statistics revision changes
- selected period changes
- selected date changes
- comparison interval changes
- goal duration changes
- current-day boundary changes
- relevant active session changes

### Chart cache

Invalidates when:

- cached PeriodStats changes
- selected period changes
- selected date changes
- relevant active session changes

### Goal consistency cache

Invalidates when:

- cached PeriodStats changes
- selected period changes
- selected date changes
- relevant active session changes

---

## Architectural Principles

The Statistics feature separates observable presentation state from internal implementation caches.

```
HistoryManager
        │
        ▼
ContinuousSessionBuilder
        │
        ▼
StatisticsStore
        │
        ├── Observable State          (@Observable — participates in SwiftUI invalidation)
        │     • dailySummaries
        │     • statisticsRevision
        │
        └── @ObservationIgnored Caches  (invisible to Observation — never invalidate views)
              • cachedPeriodStats
              • cachedChartData
              • cachedGoalData
```

Only observable presentation data participates in SwiftUI invalidation.

Implementation caches remain internal and invisible to Observation.

---

## Performance Benefits

The optimization removes:

- repeated `PeriodStats` reconstruction
- repeated chart generation
- repeated goal grouping
- duplicate synchronization
- render-time disk I/O
- repeated scans across `dailySummaries`
- unstable chart identities
- Observation render loops

The Statistics feature now performs work only when its actual inputs change, while ordinary SwiftUI body evaluations remain lightweight.

This preserves identical behavior while significantly reducing unnecessary CPU usage and recomputation.
