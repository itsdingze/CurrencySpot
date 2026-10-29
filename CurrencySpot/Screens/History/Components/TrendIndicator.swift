import SwiftUI

struct TrendIndicator: View {
    let value: String
    let direction: TrendDirection

    var body: some View {
        HStack(spacing: Spacing.hairline) {
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
        .font(.appSubheadline.weight(.medium))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(changeAccessibilityLabel)
    }

    private var changeAccessibilityLabel: LocalizedStringResource {
        switch direction {
        case .up: .historyTrendIndicatorUp(change: value)
        case .down: .historyTrendIndicatorDown(change: value)
        case .stable: .historyTrendIndicatorStable(change: value)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        TrendIndicator(value: "0.28%", direction: .down)
        TrendIndicator(value: "0.32%", direction: .up)
        TrendIndicator(value: "0.00%", direction: .stable)
    }
    .padding()
}
