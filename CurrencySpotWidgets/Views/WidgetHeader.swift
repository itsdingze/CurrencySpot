import SwiftUI

struct WidgetHeader: View {
    let base: CurrencyCode
    var target: CurrencyCode?
    let period: TimeRange

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.hairline) {
                titleText

                Text(period.shortName)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(period.displayName)
            }

            titleText
        }
        .font(.appFootnote.weight(.semibold))
    }

    private var titleText: some View {
        Text(title)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(accessibilityLabel)
    }

    private var title: AttributedString {
        var text = AttributedString("\(base.rawValue) →")
        text.foregroundColor = Color.secondary
        if let target {
            text += AttributedString(" \(target.rawValue)")
        }
        return text
    }

    private var accessibilityLabel: String {
        guard let target else { return base.uncachedLocalizedName }
        return String(localized: .widgetPairRateAccessibilityLabel(
            base: base.uncachedLocalizedName,
            target: target.uncachedLocalizedName
        ))
    }
}
