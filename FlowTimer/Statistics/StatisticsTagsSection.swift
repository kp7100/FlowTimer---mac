import SwiftUI

struct StatisticsTagsSection: View {
    let stats: PeriodStats
    
    var body: some View {
        let totalTagTime = stats.topTags.reduce(0) { $0 + $1.1 }
        
        VStack(spacing: 10) {
            if stats.topTags.isEmpty || totalTagTime == 0 {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    
                    Text("No tags yet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Add a tag while starting\na focus session.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .padding(.vertical, 8)
            } else {
                ForEach(stats.topTags, id: \.0) { tag in
                    let tagTime = tag.1
                    let fraction = totalTagTime > 0 ? tagTime / totalTagTime : 0
                    
                    HStack(spacing: 8) {
                        Image(systemName: tagIcon(for: tag.0))
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        
                        Text(tag.0)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 50, alignment: .leading)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.08))
                                if fraction > 0 {
                                    Capsule()
                                        .fill(Color.orange)
                                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(fraction))))
                                }
                            }
                        }
                        .frame(height: 5)
                        
                        Text(TimeFormatter.formatForStats(seconds: tagTime))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .modifier(CardModifier())
    }
    
    private func tagIcon(for tagName: String) -> String {
        switch tagName.lowercased() {
        case "work": return "briefcase"
        case "study": return "academiccap"
        case "reading": return "book"
        default: return "tag"
        }
    }
}
