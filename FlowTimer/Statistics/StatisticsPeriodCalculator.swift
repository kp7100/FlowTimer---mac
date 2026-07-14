import SwiftUI

struct CardModifier: ViewModifier {
    var fillHeight: Bool = false
    
    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
            )
    }
}

enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var id: String { self.rawValue }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let date: Date
}

struct PeriodStats {
    let totalFocusTime: TimeInterval
    let comparisonMinutes: Int
    let longestSession: TimeInterval
    let averageSessionLength: TimeInterval
    let completedSessions: Int
    let pauseCount: Int
    let averagePausesPerSession: Double
    let topTags: [(String, TimeInterval)]
    let daysMeetingGoal: Int
    let totalDaysInPeriod: Int
    let focusRecords: [SessionRecord]
}

struct ContinuousSession {
    let duration: TimeInterval
    let pauseCount: Int
    let tag: String?
}

struct StatisticsPeriodCalculator {
    static func calculate(for interval: DateInterval, comparisonInterval: DateInterval, allSessions: [SessionRecord], goalFocusTime: TimeInterval) -> PeriodStats {
        let periodRecords = allSessions.filter { interval.contains($0.endDate) }
        let comparisonRecords = allSessions.filter { comparisonInterval.contains($0.endDate) }
        
        let focusRecords = periodRecords.filter { $0.phase == .work || $0.phase == .flowExtension }
        let compFocusRecords = comparisonRecords.filter { $0.phase == .work || $0.phase == .flowExtension }
        
        let totalFocusTime = focusRecords.reduce(0) { $0 + $1.duration }
        let compTotalFocusTime = compFocusRecords.reduce(0) { $0 + $1.duration }
        
        let continuousSessions = getContinuousSessions(from: focusRecords)
        
        let longestSession = continuousSessions.map { $0.duration }.max() ?? 0
        let averageSessionLength = continuousSessions.isEmpty ? 0 : totalFocusTime / Double(continuousSessions.count)
        let completedSessions = continuousSessions.count
        
        let pauseCount = focusRecords.reduce(0) { $0 + $1.pauses }
        let averagePauses = completedSessions == 0 ? 0.0 : Double(pauseCount) / Double(completedSessions)
        
        var tagDict: [String: TimeInterval] = [:]
        for r in focusRecords {
            if let tag = r.tag {
                tagDict[tag, default: 0] += r.duration
            }
        }
        let topTags = tagDict.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        
        let comparisonDiffMinutes = Int((totalFocusTime - compTotalFocusTime) / 60.0)
        
        var dailyTotals: [Date: TimeInterval] = [:]
        for r in focusRecords {
            let day = Calendar.current.startOfDay(for: r.endDate)
            dailyTotals[day, default: 0] += r.duration
        }
        let daysMeetingGoal = dailyTotals.values.filter { $0 >= goalFocusTime }.count
        
        let totalDaysInPeriod: Int
        let now = Date()
        if interval.contains(now) {
            let startOfToday = Calendar.current.startOfDay(for: now)
            if let days = Calendar.current.dateComponents([.day], from: interval.start, to: startOfToday).day {
                totalDaysInPeriod = max(1, days + 1)
            } else {
                totalDaysInPeriod = 1
            }
        } else {
            if let days = Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day {
                totalDaysInPeriod = max(1, days)
            } else {
                totalDaysInPeriod = 1
            }
        }
        
        return PeriodStats(
            totalFocusTime: totalFocusTime,
            comparisonMinutes: comparisonDiffMinutes,
            longestSession: longestSession,
            averageSessionLength: averageSessionLength,
            completedSessions: completedSessions,
            pauseCount: pauseCount,
            averagePausesPerSession: averagePauses,
            topTags: topTags,
            daysMeetingGoal: daysMeetingGoal,
            totalDaysInPeriod: totalDaysInPeriod,
            focusRecords: focusRecords
        )
    }
    
    private static func getContinuousSessions(from records: [SessionRecord]) -> [ContinuousSession] {
        let sortedRecords = records.sorted(by: { $0.startDate < $1.startDate })
        var result: [ContinuousSession] = []
        
        var activeDuration: TimeInterval = 0
        var activePauses: Int = 0
        var activeTag: String? = nil
        var lastEndDate: Date? = nil
        
        for record in sortedRecords {
            if record.phase == .work {
                if record.continuationOf != nil && activeDuration > 0 {
                    activeDuration += record.duration
                    activePauses += record.pauses
                    lastEndDate = record.endDate
                } else {
                    if activeDuration > 0 {
                        result.append(ContinuousSession(duration: activeDuration, pauseCount: activePauses, tag: activeTag))
                    }
                    activeDuration = record.duration
                    activePauses = record.pauses
                    activeTag = record.tag
                    lastEndDate = record.endDate
                }
            } else if record.phase == .flowExtension {
                if let lastEnd = lastEndDate, record.startDate.timeIntervalSince(lastEnd) < 10 {
                    activeDuration += record.duration
                    activePauses += record.pauses
                    lastEndDate = record.endDate
                } else {
                    if activeDuration > 0 {
                        result.append(ContinuousSession(duration: activeDuration, pauseCount: activePauses, tag: activeTag))
                    }
                    activeDuration = record.duration
                    activePauses = record.pauses
                    activeTag = record.tag
                    lastEndDate = record.endDate
                }
            }
        }
        
        if activeDuration > 0 {
            result.append(ContinuousSession(duration: activeDuration, pauseCount: activePauses, tag: activeTag))
        }
        
        return result
    }
}

extension Calendar {
    func dateInterval(of period: StatisticsPeriod, for refDate: Date) -> DateInterval {
        switch period {
        case .day:
            let start = startOfDay(for: refDate)
            let end = self.date(byAdding: .day, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        case .week:
            let start = dateInterval(of: .weekOfYear, for: refDate)!.start
            let end = self.date(byAdding: .weekOfYear, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        case .month:
            let start = dateInterval(of: .month, for: refDate)!.start
            let end = self.date(byAdding: .month, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        case .year:
            let start = dateInterval(of: .year, for: refDate)!.start
            let end = self.date(byAdding: .year, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        }
    }
    
    func comparisonInterval(of period: StatisticsPeriod, for interval: DateInterval) -> DateInterval {
        switch period {
        case .day:
            let start = self.date(byAdding: .day, value: -1, to: interval.start)!
            let end = interval.start
            return DateInterval(start: start, end: end)
        case .week:
            let start = self.date(byAdding: .weekOfYear, value: -1, to: interval.start)!
            let end = interval.start
            return DateInterval(start: start, end: end)
        case .month:
            let start = self.date(byAdding: .month, value: -1, to: interval.start)!
            let end = interval.start
            return DateInterval(start: start, end: end)
        case .year:
            let start = self.date(byAdding: .year, value: -1, to: interval.start)!
            let end = interval.start
            return DateInterval(start: start, end: end)
        }
    }
}
