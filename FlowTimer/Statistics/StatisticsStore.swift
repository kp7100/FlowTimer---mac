import Foundation
import Observation

@MainActor
@Observable
final class StatisticsStore {
    static let shared = StatisticsStore()
    
    // The main cache: mapping calendar days to their respective DailySummary
    private(set) var dailySummaries: [Date: DailySummary] = [:]
    
    // Background worker for merging continuous sessions
    private let builder = ContinuousSessionBuilder()
    
    // Tracks which history revision this store has synced up to
    private var syncedRevision: Int = -1
    // Advances only when the history change affects statistics data.
    private var statisticsRevision: Int = 0

    private struct PeriodStatsCacheKey: Equatable {
        let statisticsRevision: Int
        let period: StatisticsPeriod
        let intervalStart: Date
        let intervalEnd: Date
        let comparisonStart: Date
        let comparisonEnd: Date
        let goalFocusTime: TimeInterval
        let currentDay: Date
    }

    private struct CachedPeriodStats {
        let key: PeriodStatsCacheKey
        let stats: PeriodStats
        let comparisonDuration: TimeInterval
    }

    /// Stable identity for the live overlay used by chart and goal caches.
    /// The timer can create a new SessionRecord with a subsecond endDate on
    /// every render, even when the visible statistics have not changed.
    private struct ActiveSessionCacheKey: Equatable {
        let id: UUID
        let phase: TimerPhase
        let startDate: Date
        let endDateSecond: Int64
        let durationSecond: Int
        let tag: String?
        let pauseCount: Int

        init(_ record: SessionRecord) {
            id = record.id
            phase = record.phase
            startDate = record.startDate
            endDateSecond = Int64(record.endDate.timeIntervalSinceReferenceDate.rounded(.down))
            durationSecond = Int(record.duration.rounded(.down))
            tag = record.tag
            pauseCount = record.pauses
        }
    }

    private struct DerivedDataCacheKey: Equatable {
        let statisticsRevision: Int
        let period: StatisticsPeriod
        let date: Date
        let calendar: Calendar
        let activeSession: ActiveSessionCacheKey?
        let totalDaysInPeriod: Int
    }

    private struct CachedChartData {
        let key: DerivedDataCacheKey
        let data: [ChartDataPoint]
    }

    private struct CachedGoalData {
        let key: DerivedDataCacheKey
        let dailyDurations: [TimeInterval]
    }

    @ObservationIgnored private var cachedPeriodStats: CachedPeriodStats?
    @ObservationIgnored private var cachedChartData: CachedChartData?
    @ObservationIgnored private var cachedGoalData: CachedGoalData?
    
    private init() {}
    
    /// Synchronizes the cache with HistoryManager if there are new changes.
    func sync() async {
        let currentRevision = HistoryManager.shared.historyRevision
        guard currentRevision != syncedRevision else { return }
        
        let records = HistoryManager.shared.sessions // Value copy safely passed to background
        
        // Hop off the main actor to do the heavy lifting
        let (updatedSessions, affectedDates) = await builder.sync(with: records)
        
        var statisticsChanged = false

        // Return to main actor to update the UI-bound cache
        if affectedDates.isEmpty && records.isEmpty {
            // History was completely cleared
            statisticsChanged = !dailySummaries.isEmpty
            self.dailySummaries.removeAll()
        } else if !affectedDates.isEmpty {
            statisticsChanged = true
            let calendar = Calendar.current
            // If it's our first sync, we rebuild all dates. Otherwise, just the affected ones.
            let datesToRebuild = syncedRevision == -1 
                ? Set(updatedSessions.map { calendar.startOfDay(for: $0.startDate) })
                : affectedDates
            
            for date in datesToRebuild {
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: date)!
                
                // Find all continuous sessions that *started* on this specific date
                let sessionsForDay = updatedSessions.filter { $0.startDate >= date && $0.startDate < dayEnd }
                
                let totalDuration = sessionsForDay.reduce(0) { $0 + $1.duration }
                let pauses = sessionsForDay.reduce(0) { $0 + $1.pauseCount }
                
                let summary = DailySummary(
                    date: date,
                    totalFocusDuration: totalDuration,
                    completedSessions: sessionsForDay.filter { $0.isCompleted }.count,
                    pauseCount: pauses,
                    sessions: sessionsForDay
                )
                
                self.dailySummaries[date] = summary
            }
        }
        
        self.syncedRevision = currentRevision

        if statisticsChanged {
            statisticsRevision += 1

            // The source data changed, so all render-derived caches must be
            // rebuilt on their next access.
            cachedPeriodStats = nil
            cachedChartData = nil
            cachedGoalData = nil
        }
    }
    
    /// Gets aggregated PeriodStats for a given interval by rolling up DailySummaries
    func getStats(
        for period: StatisticsPeriod,
        interval: DateInterval,
        comparisonInterval: DateInterval,
        goalFocusTime: TimeInterval,
        activeRecord: SessionRecord? = nil
    ) -> PeriodStats {
        let key = PeriodStatsCacheKey(
            statisticsRevision: statisticsRevision,
            period: period,
            intervalStart: interval.start,
            intervalEnd: interval.end,
            comparisonStart: comparisonInterval.start,
            comparisonEnd: comparisonInterval.end,
            goalFocusTime: goalFocusTime,
            currentDay: Calendar.current.startOfDay(for: Date())
        )

        let cached: CachedPeriodStats
        if let cachedPeriodStats, cachedPeriodStats.key == key {
            cached = cachedPeriodStats
        } else {
            let rebuilt = buildHistoricalStats(
                for: interval,
                comparisonInterval: comparisonInterval,
                goalFocusTime: goalFocusTime,
                key: key
            )
            cachedPeriodStats = rebuilt
            cached = rebuilt
        }

        guard let activeRecord = relevantActiveRecord(activeRecord, for: interval) else {
            return cached.stats
        }

        return applying(activeRecord, to: cached.stats, comparisonDuration: cached.comparisonDuration)
    }

    /// Returns cached chart buckets for the already-computed statistics.
    func chartData(
        for period: StatisticsPeriod,
        date: Date,
        interval: DateInterval,
        stats: PeriodStats,
        activeRecord: SessionRecord?
    ) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let relevantActive = relevantActiveRecord(activeRecord, for: interval)
        let key = DerivedDataCacheKey(
            statisticsRevision: statisticsRevision,
            period: period,
            date: date,
            calendar: calendar,
            activeSession: relevantActive.map(ActiveSessionCacheKey.init),
            totalDaysInPeriod: stats.totalDaysInPeriod
        )

        if let cachedChartData, cachedChartData.key == key {
            return cachedChartData.data
        }

        let data = StatisticsChartCard.makeData(
            period: period,
            date: date,
            focusRecords: stats.focusRecords
        )
        cachedChartData = CachedChartData(key: key, data: data)
        return data
    }

    /// Returns the daily focus totals used by the week/month goal grid.
    func goalConsistencyData(
        for period: StatisticsPeriod,
        date: Date,
        interval: DateInterval,
        stats: PeriodStats,
        activeRecord: SessionRecord?
    ) -> [TimeInterval] {
        let calendar = Calendar.current
        let relevantActive = relevantActiveRecord(activeRecord, for: interval)
        let key = DerivedDataCacheKey(
            statisticsRevision: statisticsRevision,
            period: period,
            date: date,
            calendar: calendar,
            activeSession: relevantActive.map(ActiveSessionCacheKey.init),
            totalDaysInPeriod: stats.totalDaysInPeriod
        )

        if let cachedGoalData, cachedGoalData.key == key {
            return cachedGoalData.dailyDurations
        }

        let numDays = stats.totalDaysInPeriod
        var dailyDurations = Array(repeating: 0.0, count: numDays)
        for record in stats.focusRecords {
            if let daysSinceStart = calendar.dateComponents([.day], from: interval.start, to: calendar.startOfDay(for: record.endDate)).day,
               daysSinceStart >= 0,
               daysSinceStart < numDays {
                dailyDurations[daysSinceStart] += record.duration
            }
        }

        cachedGoalData = CachedGoalData(key: key, dailyDurations: dailyDurations)
        return dailyDurations
    }

    private func relevantActiveRecord(_ record: SessionRecord?, for interval: DateInterval) -> SessionRecord? {
        guard let record,
              (record.phase == .work || record.phase == .flowExtension),
              interval.contains(record.endDate) else {
            return nil
        }
        return record
    }

    private func buildHistoricalStats(
        for interval: DateInterval,
        comparisonInterval: DateInterval,
        goalFocusTime: TimeInterval,
        key: PeriodStatsCacheKey
    ) -> CachedPeriodStats {
        var currentDuration: TimeInterval = 0
        var currentCompleted = 0
        var currentPauses = 0
        var longestSession: TimeInterval = 0
        var focusRecords: [SessionRecord] = []
        var tagDict: [String: TimeInterval] = [:]
        
        // Sum current and comparison periods in one pass over the daily cache.
        var daysMeetingGoalCount = 0
        var previousDuration: TimeInterval = 0

        for (date, summary) in dailySummaries {
            if interval.contains(date) {
                currentDuration += summary.totalFocusDuration
                currentCompleted += summary.completedSessions
                currentPauses += summary.pauseCount
                
                for session in summary.sessions {
                    longestSession = max(longestSession, session.duration)
                    focusRecords.append(contentsOf: session.constituentRecords)
                    if let tag = session.tag {
                        tagDict[tag, default: 0] += session.duration
                    }
                }
                
                if summary.totalFocusDuration >= goalFocusTime {
                    daysMeetingGoalCount += 1
                }
            }
            if comparisonInterval.contains(date) {
                previousDuration += summary.totalFocusDuration
            }
        }
        
        let avgLength = currentCompleted > 0 ? currentDuration / Double(currentCompleted) : 0
        let avgPauses = currentCompleted > 0 ? Double(currentPauses) / Double(currentCompleted) : 0
        let comparisonDiffMinutes = Int((currentDuration - previousDuration) / 60.0)
        let topTags = tagDict.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        
        let totalDaysInPeriod: Int
        let now = Date()
        let calendar = Calendar.current
        if interval.contains(now) {
            let startOfToday = calendar.startOfDay(for: now)
            if let days = calendar.dateComponents([.day], from: interval.start, to: startOfToday).day {
                totalDaysInPeriod = max(1, days + 1)
            } else {
                totalDaysInPeriod = 1
            }
        } else {
            if let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day {
                totalDaysInPeriod = max(1, days)
            } else {
                totalDaysInPeriod = 1
            }
        }
        
        let stats = PeriodStats(
            totalFocusTime: currentDuration,
            comparisonMinutes: comparisonDiffMinutes,
            longestSession: longestSession,
            averageSessionLength: avgLength,
            completedSessions: currentCompleted,
            pauseCount: currentPauses,
            averagePausesPerSession: avgPauses,
            topTags: topTags,
            daysMeetingGoal: daysMeetingGoalCount,
            totalDaysInPeriod: totalDaysInPeriod,
            focusRecords: focusRecords.sorted(by: { $0.startDate < $1.startDate }) // Keep sorted for charts
        )

        return CachedPeriodStats(
            key: key,
            stats: stats,
            comparisonDuration: previousDuration
        )
    }

    private func applying(_ active: SessionRecord, to stats: PeriodStats, comparisonDuration: TimeInterval) -> PeriodStats {
        let totalFocusTime = stats.totalFocusTime + active.duration
        let pauseCount = stats.pauseCount + active.pauses
        var tagDurations = Dictionary(uniqueKeysWithValues: stats.topTags)
        if let tag = active.tag {
            tagDurations[tag, default: 0] += active.duration
        }

        let focusRecords = inserting(active, into: stats.focusRecords)
        let topTags = tagDurations.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }

        return PeriodStats(
            totalFocusTime: totalFocusTime,
            comparisonMinutes: Int((totalFocusTime - comparisonDuration) / 60.0),
            longestSession: max(stats.longestSession, active.duration),
            averageSessionLength: stats.completedSessions > 0 ? totalFocusTime / Double(stats.completedSessions) : 0,
            completedSessions: stats.completedSessions,
            pauseCount: pauseCount,
            averagePausesPerSession: stats.completedSessions > 0 ? Double(pauseCount) / Double(stats.completedSessions) : 0,
            topTags: topTags,
            daysMeetingGoal: stats.daysMeetingGoal,
            totalDaysInPeriod: stats.totalDaysInPeriod,
            focusRecords: focusRecords
        )
    }

    private func inserting(_ record: SessionRecord, into records: [SessionRecord]) -> [SessionRecord] {
        var result = records
        let insertionIndex = records.firstIndex { $0.startDate > record.startDate } ?? records.endIndex
        result.insert(record, at: insertionIndex)
        return result
    }
}
