import SwiftUI

struct TrendChange: View {
    let value: String
    let direction: TrendDirection

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: direction.systemImage)
                .imageScale(.small)
                .accessibilityHidden(true)

            Text(value)
                .monospacedDigit()
        }
        .font(.appFootnote.weight(.semibold))
        .foregroundStyle(direction.color)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: LocalizedStringResource {
        switch direction {
        case .up: .historyTrendIndicatorUp(change: value)
        case .down: .historyTrendIndicatorDown(change: value)
        case .stable: .historyTrendIndicatorStable(change: value)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Spacing.tight) {
        TrendChange(value: "1.88%", direction: .up)
        TrendChange(value: "0.41%", direction: .down)
        TrendChange(value: "0.05%", direction: .stable)
    }
    .padding()
}
