import SwiftUI

struct StatisticsHeroCard: View {
    let stats: PeriodStats
    let period: StatisticsPeriod
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus Time")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(TimeFormatter.formatForStats(seconds: stats.totalFocusTime))
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                
                // Comparison Badge closely aligned below focus time
                HStack(spacing: 3) {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 6))
                        .rotationEffect(stats.comparisonMinutes >= 0 ? .zero : .degrees(180))
                    Text(formatComparison(stats.comparisonMinutes))
                        .font(.system(size: 11, weight: .medium))
                        .contentTransition(.numericText())
                }
                .foregroundColor(stats.comparisonMinutes >= 0 ? .orange : .secondary)
                .padding(.top, 2)
            }
            
            Spacer()
            
            // Soft Clock Icon on Right
            Image(systemName: "clock")
                .font(.system(size: 20))
                .foregroundColor(.orange)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
        }
        .modifier(CardModifier(fillHeight: true))
    }
    
    private func formatComparison(_ mins: Int) -> String {
        let absMins = abs(mins)
        let periodLabel: String
        switch period {
        case .day: periodLabel = "yesterday"
        case .week: periodLabel = "last week"
        case .month: periodLabel = "last month"
        case .year: periodLabel = "last year"
        }
        
        if absMins >= 60 {
            let h = absMins / 60
            let m = absMins % 60
            if m > 0 {
                return "\(h)h \(m)m vs \(periodLabel)"
            } else {
                return "\(h)h vs \(periodLabel)"
            }
        } else {
            return "\(absMins)m vs \(periodLabel)"
        }
    }
}

struct StatisticsGoalCard: View {
    let stats: PeriodStats
    let period: StatisticsPeriod
    let dailyDurations: [TimeInterval]
    
    var body: some View {
        let settings = SettingsManager.shared.settings
        let target = settings.goalFocusTime
        
        if period == .day {
            let fraction = target > 0 ? stats.totalFocusTime / target : 0
            let isCompleted = stats.totalFocusTime >= target
            let mainText = "\(TimeFormatter.formatForStats(seconds: stats.totalFocusTime)) / \(TimeFormatter.formatForStats(seconds: target))"
            
            return AnyView(
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Goal Progress")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(mainText)
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        
                        // Bottom integrated progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.08))
                                if stats.totalFocusTime > 0 && fraction > 0 {
                                    Capsule()
                                        .fill(isCompleted ? Color.green : Color.accentColor)
                                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(fraction))))
                                }
                            }
                        }
                        .frame(height: 6)
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    CircularProgressRing(fraction: fraction, isCompleted: isCompleted)
                }
                .modifier(CardModifier(fillHeight: true))
            )
        } else {
            return AnyView(
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Goal Consistency")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        GoalConsistencyVisualizer(
                            period: period,
                            dailyDurations: dailyDurations,
                            goalFocusTime: target
                        )
                        .padding(.vertical, 4)
                        
                        Text("\(stats.daysMeetingGoal) / \(stats.totalDaysInPeriod) days")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                }
                .modifier(CardModifier(fillHeight: true))
            )
        }
    }
}

struct GoalConsistencyVisualizer: View {
    let period: StatisticsPeriod
    let dailyDurations: [TimeInterval]
    let goalFocusTime: TimeInterval
    
    var body: some View {
        let numDays = dailyDurations.count
        
        let cols = Array(repeating: GridItem(.fixed(8), spacing: 6), count: period == .month ? 10 : 7)
        
        return LazyVGrid(columns: cols, alignment: .leading, spacing: 6) {
            ForEach(0..<numDays, id: \.self) { i in
                let met = dailyDurations[i] >= goalFocusTime
                Circle()
                    .fill(met ? Color.accentColor : Color.secondary.opacity(0.15))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

struct CircularProgressRing: View {
    let fraction: Double
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.08), lineWidth: 4)
            if fraction > 0 {
                Circle()
                    .trim(from: 0.0, to: min(fraction, 1.0))
                    .stroke(
                        isCompleted ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
            }
            
            Text("\(Int(min(fraction, 1.0) * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
        }
        .frame(width: 44, height: 44)
    }
}
