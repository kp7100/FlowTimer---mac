import SwiftUI

struct StatisticCard: View {
    let title: String
    let value: String
    let subtitle: String
    let iconName: String
    var fillHeight: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(.orange)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text(value)
                .font(.system(size: 22, weight: value == "—" ? .medium : .bold))
                .foregroundColor(value == "—" ? .secondary : .primary)
                .lineLimit(1)
                .contentTransition(.numericText())
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .modifier(CardModifier(fillHeight: fillHeight))
    }
}
