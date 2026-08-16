import SwiftUI

struct UnifiedCurrencyView: View {
    enum DisplayType {
        case source
        case converted

        var title: String {
            switch self {
            case .source:
                "From"
            case .converted:
                "To"
            }
        }

        var titleColor: Color {
            switch self {
            case .source:
                .textSecondary
            case .converted:
                .accentColor
            }
        }

        var amountColor: Color {
            switch self {
            case .source:
                .textPrimary
            case .converted:
                .accentColor
            }
        }

        var buttonColor: Color {
            switch self {
            case .source:
                .textSecondary
            case .converted:
                .accentColor
            }
        }

        var backgroundColor: Color {
            switch self {
            case .source:
                .textSecondary.opacity(0.2)
            case .converted:
                .selectionFill
            }
        }

        var strokeColor: Color {
            switch self {
            case .source:
                .textSecondary.opacity(0.1)
            case .converted:
                .accentColor.opacity(0.1)
            }
        }
    }

    let type: DisplayType
    let amount: String
    let currencyCode: CurrencyCode
    let onPress: () -> Void

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
            .foregroundStyle(type.titleColor)
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
            .foregroundStyle(type.amountColor)
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
        let currency = CurrencyNameLookup.name(for: currencyCode)
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
        .buttonStyle(.currencyCode(fill: type.backgroundColor, stroke: type.strokeColor))
        .foregroundStyle(type.buttonColor)
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
        let currencyName = CurrencyNameLookup.name(for: currencyCode)
        return "Currently selected: \(currencyName), \(currencyCode.rawValue)"
    }

    private var accessibilityInputLabels: [String] {
        let currencyName = CurrencyNameLookup.name(for: currencyCode)
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
