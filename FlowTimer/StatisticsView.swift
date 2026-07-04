import SwiftUI

struct StatisticsView: View {
    @Bindable var historyManager = HistoryManager.shared
    
    var body: some View {
        if historyManager.sessions.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No sessions yet.")
                    .font(.headline)
                Text("Complete your first focus session to start building statistics.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .frame(width: 400, height: 500)
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    StatSection(title: "Today",
                                focusTime: historyManager.focusTimeToday(),
                                flowTime: historyManager.flowExtensionToday(),
                                count: historyManager.completedWorkSessionsToday(),
                                longestFlow: historyManager.longestFlow())
                    
                    Divider()
                    
                    StatSection(title: "Yesterday",
                                focusTime: historyManager.focusTimeYesterday(),
                                flowTime: historyManager.flowExtensionYesterday(),
                                count: historyManager.sessionsYesterday())
                    
                    Divider()
                    
                    StatSection(title: "This Week",
                                focusTime: historyManager.focusTimeThisWeek(),
                                flowTime: historyManager.flowExtensionThisWeek(),
                                count: historyManager.completedWorkSessionsThisWeek())
                    
                    Divider()
                    
                    StatSection(title: "This Month",
                                focusTime: historyManager.focusTimeThisMonth(),
                                flowTime: historyManager.flowExtensionThisMonth(),
                                count: historyManager.completedWorkSessionsThisMonth())
                    
                    Divider()
                    
                    StatSection(title: "All Time",
                                focusTime: historyManager.totalFocusTime(),
                                flowTime: historyManager.totalFlowExtension(),
                                count: historyManager.totalCompletedWorkSessions())
                    
                    let tags = historyManager.topTags(limit: 5)
                    if !tags.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Tags")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            ForEach(tags, id: \.0) { tag in
                                HStack {
                                    Text(tag.0)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(TimeFormatter.formatForStats(seconds: tag.1))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(width: 400, height: 540)
        }
    }
}

struct StatSection: View {
    let title: String
    let focusTime: TimeInterval
    let flowTime: TimeInterval
    let count: Int
    var longestFlow: TimeInterval? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                StatItem(label: "Focus Time", value: TimeFormatter.formatForStats(seconds: focusTime))
                Spacer()
                StatItem(label: "Flow Extension", value: TimeFormatter.formatForStats(seconds: flowTime))
            }
            
            HStack {
                StatItem(label: "Sessions", value: "\(count)")
                Spacer()
                if let longest = longestFlow, longest > 0 {
                    StatItem(label: "Longest Flow", value: TimeFormatter.formatForStats(seconds: longest))
                } else {
                    Spacer().frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
