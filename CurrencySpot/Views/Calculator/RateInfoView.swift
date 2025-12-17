//
//  RateInfoView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/1/25.
//

import SwiftUI

struct RateInfoView: View {
    @Environment(CalculatorViewModel.self) private var viewModel: CalculatorViewModel

    private let itemSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: itemSpacing) {
            if shouldShowConversionRate {
                conversionRateText
            }
            lastUpdatedText
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityContainerLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var accessibilityContainerLabel: String {
        var label = "Exchange rate information. "
        if shouldShowConversionRate {
            label += "Current rate: \(formattedConversionRate). "
        }
        label += "Last updated: \(viewModel.formattedLastUpdated)"
        return label
    }

    // MARK: - Private Views

    @ViewBuilder
    private var conversionRateText: some View {
        Text(formattedConversionRate)
            .font(.system(.caption, design: .rounded))
            .foregroundColor(.textSecondary)
            .accessibilityLabel("Current exchange rate: \(formattedConversionRate)")
            .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private var lastUpdatedText: some View {
        Text(viewModel.formattedLastUpdated)
            .font(.system(.caption2, design: .rounded))
            .foregroundColor(.textSecondary)
            .accessibilityLabel("Exchange rates last updated: \(viewModel.formattedLastUpdated)")
    }

    // MARK: - Private Properties

    private var shouldShowConversionRate: Bool {
        viewModel.baseCurrency != viewModel.targetCurrency
    }

    private var formattedConversionRate: String {
        "1 \(viewModel.baseCurrency) = \(viewModel.conversionRate.toStringMax4Decimals) \(viewModel.targetCurrency)"
    }
}
