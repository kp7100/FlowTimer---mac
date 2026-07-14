import SwiftUI

struct StatisticsHeader: View {
    @Binding var selectedPeriod: StatisticsPeriod
    @Binding var selectedDate: Date
    let title: String
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(StatisticsPeriod.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)
            
            HStack {
                Button(action: { navigate(direction: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.secondary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { navigate(direction: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.secondary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .disabled(isFutureLimitReached())
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func navigate(direction: Int) {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: direction, to: selectedDate)!
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate)!
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: direction, to: selectedDate)!
        case .year:
            selectedDate = calendar.date(byAdding: .year, value: direction, to: selectedDate)!
        }
    }
    
    private func isFutureLimitReached() -> Bool {
        let calendar = Calendar.current
        let nextDate: Date
        switch selectedPeriod {
        case .day:
            nextDate = calendar.date(byAdding: .day, value: 1, to: selectedDate)!
        case .week:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate)!
        case .month:
            nextDate = calendar.date(byAdding: .month, value: 1, to: selectedDate)!
        case .year:
            nextDate = calendar.date(byAdding: .year, value: 1, to: selectedDate)!
        }
        
        let startOfNext = calendar.startOfDay(for: nextDate)
        let startOfCurrentLimit = calendar.startOfDay(for: Date())
        
        return startOfNext > startOfCurrentLimit
    }
}
