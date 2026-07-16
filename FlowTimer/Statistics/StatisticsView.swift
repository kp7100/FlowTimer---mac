import SwiftUI
import Charts

struct StatisticsView: View {
    @Bindable var historyManager = HistoryManager.shared
    var timerManager: TimerManager
    @State private var selectedPeriod: StatisticsPeriod = .day
    @State private var selectedDate: Date = Date()
    
    @State private var store = StatisticsStore.shared

    
    var body: some View {
        let interval = Calendar.current.dateInterval(of: selectedPeriod, for: selectedDate)
        let compInterval = Calendar.current.comparisonInterval(of: selectedPeriod, for: interval)
        
        let stats = store.getStats(
            for: interval,
            comparisonInterval: compInterval,
            goalFocusTime: SettingsManager.shared.settings.goalFocusTime,
            activeRecord: timerManager.activeSessionRecord
        )
        
        VStack(spacing: 0) {
            // Header is always visible
            StatisticsHeader(
                selectedPeriod: $selectedPeriod,
                selectedDate: $selectedDate,
                title: periodTitle(for: selectedDate, period: selectedPeriod)
            )
            .padding()
            
            if stats.completedSessions == 0 && stats.totalFocusTime == 0 {
                EmptyStatisticsView()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Hero Cards (Focus Time & Goal Progress side-by-side)
                        HStack(spacing: 16) {
                            StatisticsHeroCard(stats: stats, period: selectedPeriod)
                            if selectedPeriod != .year {
                                StatisticsGoalCard(stats: stats, period: selectedPeriod, selectedDate: selectedDate)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        
                        // Chart Card
                        StatisticsChartCard(period: selectedPeriod, date: selectedDate, focusRecords: stats.focusRecords)
                        
                        // Session Quality Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session Quality")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            HStack(spacing: 16) {
                                StatisticCard(
                                    title: "Longest Session",
                                    value: stats.completedSessions > 0 ? TimeFormatter.formatForStats(seconds: stats.longestSession) : "—",
                                    subtitle: "",
                                    iconName: "arrow.up.forward.circle",
                                    fillHeight: true
                                )
                                
                                StatisticCard(
                                    title: "Average Session",
                                    value: stats.completedSessions > 0 ? TimeFormatter.formatForStats(seconds: stats.averageSessionLength) : "—",
                                    subtitle: "",
                                    iconName: "clock",
                                    fillHeight: true
                                )
                                
                                StatisticCard(
                                    title: "Focus Sessions",
                                    value: "\(stats.completedSessions)",
                                    subtitle: "Completed",
                                    iconName: "checkmark.circle",
                                    fillHeight: true
                                )
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Focus Quality Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Focus Quality")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            HStack(spacing: 16) {
                                StatisticCard(
                                    title: "Pause Count",
                                    value: "\(stats.pauseCount)",
                                    subtitle: selectedPeriod == .day ? "Today" : "This Period",
                                    iconName: "pause.circle",
                                    fillHeight: true
                                )
                                
                                StatisticCard(
                                    title: "Avg Pauses / Session",
                                    value: stats.completedSessions > 0 ? formatAveragePauses(stats.averagePausesPerSession) : "—",
                                    subtitle: "Per Session",
                                    iconName: "hand.raised",
                                    fillHeight: true
                                )
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Top Tags Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top Tags")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            StatisticsTagsSection(stats: stats)
                        }
                        
                        // Footnote
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                            Text("All times include Flow Extension")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    }
                    .padding()
                }
                .animation(.easeInOut(duration: 0.25), value: selectedPeriod)
                .animation(.easeInOut(duration: 0.25), value: selectedDate)
            }
        }
        .task(id: selectedDate) { await store.sync() }
        .task(id: selectedPeriod) { await store.sync() }
        .task(id: historyManager.historyRevision) { await store.sync() }
        .task { await store.sync() }
    }
    
    private func formatAveragePauses(_ avg: Double) -> String {
        let rounded = (avg * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))"
        } else {
            return String(format: "%.1f", rounded)
        }
    }
    
    private func periodTitle(for date: Date, period: StatisticsPeriod) -> String {
        let calendar = Calendar.current
        switch period {
        case .day:
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: date)
            }
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: date)!
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: interval.start)
            
            let endDay = calendar.date(byAdding: .day, value: -1, to: interval.end)!
            
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            let endStr = endFormatter.string(from: endDay)
            return "\(startStr) – \(endStr)"
            
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
            
        case .year:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            return formatter.string(from: date)
        }
    }
}
