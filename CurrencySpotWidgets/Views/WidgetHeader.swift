import SwiftUI

struct WidgetHeader: View {
    let base: CurrencyCode
    var target: CurrencyCode?
    let period: TimeRange
    let entryDate: Date
    let outdatedFetchDate: Date?

    var body: some View {
        Group {
            if let outdatedFetchDate {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.hairline) {
                        titleText
                        updatedText(outdatedFetchDate)
                            .layoutPriority(1)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        titleText
                        updatedText(outdatedFetchDate)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.hairline) {
                        titleText

                        Text(period.shortName)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(period.displayName)
                    }

                    titleText
                }
            }
        }
        .font(.appFootnote.weight(.semibold))
    }

    private var titleText: some View {
        Text(title)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(accessibilityLabel)
    }

    private func updatedText(_ fetchDate: Date) -> some View {
        let format: Date.FormatStyle = Calendar.current.isDate(fetchDate, inSameDayAs: entryDate)
            ? .dateTime.hour().minute()
            : .dateTime.month(.abbreviated).day()
        return Text(.widgetHeaderUpdated(date: fetchDate.formatted(format)))
            .foregroundStyle(.secondary)
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
