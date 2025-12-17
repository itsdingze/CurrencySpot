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
                .accentColor.opacity(0.2)
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
        VStack(alignment: .leading, spacing: 8) {
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
        let currencyName = CurrencyUtilities.shared.name(for: currencyCode)
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
            .font(.system(.headline, design: .rounded, weight: .medium))
            .foregroundColor(type.titleColor)
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
            .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
            .foregroundColor(type.amountColor)
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
        let currency = CurrencyUtilities.shared.name(for: currencyCode)
        return "\(amount) \(currency)"
    }

    @ViewBuilder
    private var currencyButton: some View {
        Button(action: onPress) {
            HStack {
                // This applies the same width to all buttons because font is not monospaced.
                ZStack(alignment: .center) {
                    Text("WWI")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.clear)

                    Text(currencyCode)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                }

                Image(systemName: "chevron.down")
                    .font(.system(.caption, design: .rounded))
                    .bold()
            }
        }
        .foregroundColor(type.buttonColor)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(type.backgroundColor)
                .stroke(type.strokeColor, lineWidth: 1)
        )
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
        let currencyName = CurrencyUtilities.shared.name(for: currencyCode)
        return "Currently selected: \(currencyName), \(currencyCode)"
    }

    private var accessibilityInputLabels: [String] {
        let currencyName = CurrencyUtilities.shared.name(for: currencyCode)
        switch type {
        case .source:
            return ["From currency", "Source currency", currencyCode, currencyName]
        case .converted:
            return ["To currency", "Target currency", currencyCode, currencyName]
        }
    }
}
