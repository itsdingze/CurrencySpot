//
//  UnifiedCurrencyView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/4/25.
//

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
    let currencyCode: String
    let onPress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .tightGap) {
            titleView
            contentRow
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityContainerLabel)
        .accessibilityValue(accessibilityContainerValue)
        .accessibilityHint(accessibilityContainerHint)
    }

    private var accessibilityContainerLabel: String {
        switch type {
        case .source:
            "Source currency conversion"
        case .converted:
            "Target currency conversion"
        }
    }

    private var accessibilityContainerValue: String {
        let currencyName = CurrencyUtilities.name(for: currencyCode)
        return "\(amount) \(currencyName)"
    }

    private var accessibilityContainerHint: String {
        switch type {
        case .source:
            "Double tap to select source currency"
        case .converted:
            "Double tap to select target currency"
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var titleView: some View {
        Text(type.title)
            .font(.appHeadline.weight(.medium))
            .foregroundStyle(type.titleColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
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
        let currency = CurrencyUtilities.name(for: currencyCode)
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
        .buttonStyle(CurrencyCodeButtonStyle(fill: type.backgroundColor, stroke: type.strokeColor))
        .foregroundStyle(type.buttonColor)
        .accessibilityLabel(accessibilityButtonLabel)
        .accessibilityHint(accessibilityButtonHint)
        .accessibilityValue(accessibilityButtonValue)
        .accessibilityInputLabels(accessibilityInputLabels)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityButtonLabel: String {
        switch type {
        case .source:
            "Select source currency"
        case .converted:
            "Select target currency"
        }
    }

    private var accessibilityButtonHint: String {
        "Opens currency selection"
    }

    private var accessibilityButtonValue: String {
        let currencyName = CurrencyUtilities.name(for: currencyCode)
        return "Currently selected: \(currencyName), \(currencyCode)"
    }

    private var accessibilityInputLabels: [String] {
        let currencyName = CurrencyUtilities.name(for: currencyCode)
        switch type {
        case .source:
            return ["From currency", "Source currency", currencyCode, currencyName]
        case .converted:
            return ["To currency", "Target currency", currencyCode, currencyName]
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        UnifiedCurrencyView(type: .source, amount: "1,234.56", currencyCode: "USD", onPress: {})
        UnifiedCurrencyView(type: .converted, amount: "1,134.02", currencyCode: "EUR", onPress: {})
    }
    .padding()
}
