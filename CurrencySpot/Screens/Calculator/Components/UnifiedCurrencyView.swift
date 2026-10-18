import SwiftUI

struct UnifiedCurrencyView: View {
    enum DisplayType {
        case source
        case converted

        fileprivate var title: String {
            switch self {
            case .source:
                "From"
            case .converted:
                "To"
            }
        }

        fileprivate var captionStyle: AnyShapeStyle {
            switch self {
            case .source:
                AnyShapeStyle(Color.secondary)
            case .converted:
                AnyShapeStyle(.tint)
            }
        }

        fileprivate var amountStyle: AnyShapeStyle {
            switch self {
            case .source:
                AnyShapeStyle(Color.primary)
            case .converted:
                AnyShapeStyle(.tint)
            }
        }

        fileprivate func backgroundColor(accent: Color) -> Color {
            switch self {
            case .source:
                Color.secondary.opacity(0.2)
            case .converted:
                .selectionFill(on: accent)
            }
        }

        fileprivate func strokeColor(accent: Color) -> Color {
            switch self {
            case .source:
                Color.secondary.opacity(0.1)
            case .converted:
                accent.opacity(0.1)
            }
        }
    }

    let type: DisplayType
    let amount: String
    let currencyCode: CurrencyCode
    let onPress: () -> Void

    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            titleView
            contentRow
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var titleView: some View {
        Text(type.title)
            .font(.appHeadline.weight(.medium))
            .foregroundStyle(type.captionStyle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var contentRow: some View {
        HStack {
            amountText
            Spacer()
            currencyButton
        }
    }

    @ViewBuilder
    private var amountText: some View {
        Text(amount)
            .font(.appLargeTitle.monospacedDigit())
            .foregroundStyle(type.amountStyle)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(.numericText())
            .accessibilityLabel(accessibilityAmountLabel)
            .accessibilityValue(accessibilityAmountValue)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var accessibilityAmountLabel: String {
        switch type {
        case .source:
            "Amount to convert"
        case .converted:
            "Converted amount"
        }
    }

    private var accessibilityAmountValue: String {
        let currency = currencyCode.localizedName
        return "\(amount) \(currency)"
    }

    @ViewBuilder
    private var currencyButton: some View {
        Button(action: onPress) {
            HStack {
                FixedWidthCurrencyLabel(code: currencyCode)

                Image(systemName: "chevron.down")
                    .font(.appCaption)
                    .bold()
            }
        }
        .buttonStyle(.currencyCode(fill: type.backgroundColor(accent: accent), stroke: type.strokeColor(accent: accent)))
        .foregroundStyle(type.captionStyle)
        .accessibilityLabel(accessibilityButtonLabel)
        .accessibilityValue(accessibilityButtonValue)
        .accessibilityInputLabels(accessibilityInputLabels)
    }

    private var accessibilityButtonLabel: String {
        switch type {
        case .source:
            "Select source currency"
        case .converted:
            "Select target currency"
        }
    }

    private var accessibilityButtonValue: String {
        let currencyName = currencyCode.localizedName
        return "Currently selected: \(currencyName), \(currencyCode.rawValue)"
    }

    private var accessibilityInputLabels: [String] {
        let currencyName = currencyCode.localizedName
        return [currencyCode.rawValue, currencyName]
    }
}

#Preview {
    VStack(spacing: 24) {
        UnifiedCurrencyView(type: .source, amount: "1,234.56", currencyCode: .usd, onPress: {})
        UnifiedCurrencyView(type: .converted, amount: "1,134.02", currencyCode: .eur, onPress: {})
    }
    .padding()
}
