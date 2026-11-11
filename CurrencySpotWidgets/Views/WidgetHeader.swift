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
                        fetchDateText(outdatedFetchDate)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        titleText
                        fetchDateText(outdatedFetchDate)
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

    private func fetchDateText(_ fetchDate: Date) -> some View {
        let format: Date.FormatStyle = Calendar.current.isDate(fetchDate, inSameDayAs: entryDate)
            ? .dateTime.hour().minute()
            : .dateTime.month(.abbreviated).day()
        let date = fetchDate.formatted(format)
        return Text(date)
            .foregroundStyle(.secondary)
            .accessibilityLabel(.widgetHeaderUpdated(date: date))
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
