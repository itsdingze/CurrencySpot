import SwiftUI

struct FeatureRow: View {
    let symbol: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    @ScaledMetric(relativeTo: .title) private var symbolColumnWidth: CGFloat = 32

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.section) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: symbolColumnWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.tight) {
                Text(title)
                    .font(.appHeadline)

                Text(subtitle)
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        FeatureRow(
            symbol: "hand.tap",
            title: .onboardingChartToggleTitle,
            subtitle: .onboardingChartToggleSubtitle
        )

        FeatureRow(
            symbol: "chart.line.flattrend.xyaxis",
            title: .onboardingChartAverageTitle,
            subtitle: .onboardingChartAverageSubtitle
        )

        FeatureRow(
            symbol: "hand.point.up.left",
            title: .onboardingChartSelectTitle,
            subtitle: .onboardingChartSelectSubtitle
        )

        FeatureRow(
            symbol: "arrow.left.and.right",
            title: .onboardingChartDragTitle,
            subtitle: .onboardingChartDragSubtitle
        )
    }
    .padding()
}
