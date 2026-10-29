import SwiftUI

struct WidgetHeader: View {
    let base: CurrencyCode
    var target: CurrencyCode?

    var body: some View {
        Text(title)
            .font(.appFootnote.weight(.semibold))
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
