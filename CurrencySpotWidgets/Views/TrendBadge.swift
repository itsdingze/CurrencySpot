import SwiftUI

struct TrendBadge: View {
    let value: String
    let direction: TrendDirection

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "circle")
                .opacity(0)
                .overlay {
                    Image(systemName: direction.systemImage)
                }
                .accessibilityHidden(true)

            Text(value)
                .fixedSize()
                .monospacedDigit()
        }
        .foregroundStyle(direction.color)
        .font(.appCaption2.weight(.semibold))
        .imageScale(.small)
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .frame(minWidth: 58, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(direction.color.opacity(0.12))
                .strokeBorder(direction.color.opacity(0.05), lineWidth: 1)
        )
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
    VStack(alignment: .trailing, spacing: Spacing.tight) {
        TrendBadge(value: "1.88%", direction: .up)
        TrendBadge(value: "0.41%", direction: .down)
        TrendBadge(value: "0.05%", direction: .stable)
    }
    .padding()
}
