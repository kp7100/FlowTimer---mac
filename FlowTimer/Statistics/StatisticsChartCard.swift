import SwiftUI
import Charts

struct StatisticsChartCard: View {
    let period: StatisticsPeriod
    let date: Date
    let focusRecords: [SessionRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Distribution")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Text("Focus minutes by hour")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 4)
            
            let data = getChartData()
            
            if data.isEmpty || data.allSatisfy({ $0.value == 0 }) {
                VStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No focus activity")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
            } else {
                if period == .day {
                    Chart(data) { point in
                        BarMark(
                            x: .value("Time", point.date),
                            y: .value("Focus Time (m)", point.value)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 160)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                        }
                    }
                    .chartYScale(domain: 0...60)
                    .chartYAxis {
                        AxisMarks(values: [0, 15, 30, 45, 60]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            if let mins = value.as(Int.self) {
                                if mins == 60 {
                                    AxisValueLabel("1h")
                                } else {
                                    AxisValueLabel("\(mins)m")
                                }
                            }
                        }
                    }
                } else {
                    Chart(data) { point in
                        BarMark(
                            x: .value("Time", point.label),
                            y: .value("Focus Time (m)", point.value)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 160)
                    .chartXAxis {
                        AxisMarks(stroke: StrokeStyle(lineWidth: 0))
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            if let mins = value.as(Double.self) {
                                if mins >= 60 {
                                    let h = Int(mins / 60)
                                    let m = Int(mins) % 60
                                    if m > 0 {
                                        AxisValueLabel("\(h)h \(m)m")
                                    } else {
                                        AxisValueLabel("\(h)h")
                                    }
                                } else {
                                    AxisValueLabel("\(Int(mins))m")
                                }
                            }
                        }
                    }
                }
            }
        }
        .modifier(CardModifier())
    }
    
    private func getChartData() -> [ChartDataPoint] {
        let calendar = Calendar.current
        
        switch period {
        case .day:
            var binSeconds = Array(repeating: 0.0, count: 24)
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            for record in focusRecords {
                let totalElapsed = record.endDate.timeIntervalSince(record.startDate)
                guard totalElapsed > 0 else { continue }
                
                let activeRatio = min(1.0, record.duration / totalElapsed)
                
                let start = max(record.startDate, dayStart)
                let end = min(record.endDate, dayEnd)
                guard start < end else { continue }
                
                let startHour = calendar.component(.hour, from: start)
                let endHour = calendar.component(.hour, from: end)
                
                for h in startHour...endHour {
                    let hourStart = calendar.date(byAdding: .hour, value: h, to: dayStart)!
                    let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
                    
                    let overlapStart = max(start, hourStart)
                    let overlapEnd = min(end, hourEnd)
                    if overlapStart < overlapEnd {
                        let overlapElapsed = overlapEnd.timeIntervalSince(overlapStart)
                        binSeconds[h] += (overlapElapsed * activeRatio)
                    }
                }
            }
            
            return (0..<24).map { h in
                let label: String
                if h == 0 { label = "12 AM" }
                else if h == 12 { label = "12 PM" }
                else if h > 12 { label = "\(h - 12) PM" }
                else { label = "\(h) AM" }
                
                let displayMins = Double(Int(binSeconds[h]) / 60)
                return ChartDataPoint(label: label, value: displayMins, date: dayStart.addingTimeInterval(TimeInterval(h * 3600)))
            }
            
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)!.start
            var dailySeconds = Array(repeating: 0.0, count: 7)
            
            for record in focusRecords {
                let dayIndex = calendar.component(.weekday, from: record.endDate) - 1
                if dayIndex >= 0 && dayIndex < 7 {
                    dailySeconds[dayIndex] += record.duration
                }
            }
            
            let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return (0..<7).map { i in
                let displayMins = Double(Int(dailySeconds[i]) / 60)
                return ChartDataPoint(
                    label: weekdaySymbols[i],
                    value: displayMins,
                    date: calendar.date(byAdding: .day, value: i, to: weekStart)!
                )
            }
            
        case .month:
            let monthStart = calendar.dateInterval(of: .month, for: date)!.start
            let range = calendar.range(of: .day, in: .month, for: date)!
            let numDays = range.count
            var dailySeconds = Array(repeating: 0.0, count: numDays)
            
            for record in focusRecords {
                let day = calendar.component(.day, from: record.endDate)
                if day >= 1 && day <= numDays {
                    dailySeconds[day - 1] += record.duration
                }
            }
            
            return (0..<numDays).map { d in
                let dayLabel = "\(d + 1)"
                let cleanLabel = ((d + 1) % 5 == 0 || d == 0) ? dayLabel : ""
                let displayMins = Double(Int(dailySeconds[d]) / 60)
                return ChartDataPoint(
                    label: cleanLabel,
                    value: displayMins,
                    date: calendar.date(byAdding: .day, value: d, to: monthStart)!
                )
            }
            
        case .year:
            let yearStart = calendar.dateInterval(of: .year, for: date)!.start
            var monthlySeconds = Array(repeating: 0.0, count: 12)
            
            for record in focusRecords {
                let m = calendar.component(.month, from: record.endDate) - 1
                if m >= 0 && m < 12 {
                    monthlySeconds[m] += record.duration
                }
            }
            
            let monthSymbols = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            return (0..<12).map { m in
                let displayMins = Double(Int(monthlySeconds[m]) / 60)
                return ChartDataPoint(
                    label: monthSymbols[m],
                    value: displayMins,
                    date: calendar.date(byAdding: .month, value: m, to: yearStart)!
                )
            }
        }
    }
}
