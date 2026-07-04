import SwiftUI

struct StatisticsView: View {
    @Bindable var historyManager = HistoryManager.shared
    
    var body: some View {
        if historyManager.sessions.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No completed sessions yet.")
                    .font(.headline)
                Text("Complete your first focus session to start tracking your productivity.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .frame(width: 400, height: 480)
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    StatSection(title: "Today",
                                time: historyManager.focusTimeToday(),
                                count: historyManager.completedWorkSessionsToday())
                    
                    Divider()
                    
                    StatSection(title: "This Week",
                                time: historyManager.focusTimeThisWeek(),
                                count: historyManager.completedWorkSessionsThisWeek())
                    
                    Divider()
                    
                    StatSection(title: "This Month",
                                time: historyManager.focusTimeThisMonth(),
                                count: historyManager.completedWorkSessionsThisMonth())
                    
                    Divider()
                    
                    StatSection(title: "All Time",
                                time: historyManager.totalFocusTime(),
                                count: historyManager.totalCompletedWorkSessions())
                }
                .padding()
            }
            .frame(width: 400, height: 480)
        }
    }
}

struct StatSection: View {
    let title: String
    let time: TimeInterval
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Focus Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(TimeFormatter.formatForStats(seconds: time))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
