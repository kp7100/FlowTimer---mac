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

enum StatisticsPeriod: String, CaseIterable, Identifiable, Equatable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var id: String { self.rawValue }
    
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id: Date
    let label: String
    let value: Double
    let date: Date

    init(label: String, value: Double, date: Date) {
        self.id = date
        self.label = label
        self.value = value
        self.date = date
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
