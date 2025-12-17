//
//  HeaderSection.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/26/25.
//

import SwiftUI

struct HeaderSection: View {
    @Environment(HistoryViewModel.self) var historyViewModel: HistoryViewModel
    @Environment(CalculatorViewModel.self) var calculatorViewModel: CalculatorViewModel
    @Binding var isChartSelectionActive: Bool

    var body: some View {
        VStack(spacing: 16) {
            currentRateView

            TimeRangePicker(
                selectedTimeRange: Bindable(historyViewModel).selectedTimeRange
            )
            .opacity(isChartSelectionActive ? 0 : 1)
        }
    }

    // MARK: - Private Views

    private var currentRateView: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(historyViewModel.targetCurrency)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .accessibilityLabel("\(historyViewModel.targetCurrency), \(CurrencyUtilities.shared.name(for: historyViewModel.targetCurrency))")

                Text(CurrencyUtilities.shared.name(for: historyViewModel.targetCurrency))
                    .font(.system(.headline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                // Try horizontal layout first
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(historyViewModel.formattedCurrentRate)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .accessibilityLabel("Current rate: \(historyViewModel.formattedCurrentRate)")
                        .accessibilityAddTraits(.updatesFrequently)

                    // Percent change indicator
                    if let percentChange = historyViewModel.percentChange,
                       let priceChange = historyViewModel.priceChange
                    {
                        percentChangeIndicator(priceChange: priceChange, percentChange: percentChange)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                    }

                    Spacer()
                }

                // Fall back to vertical layout when horizontal doesn't fit
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(historyViewModel.formattedCurrentRate)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .accessibilityLabel("Current rate: \(historyViewModel.formattedCurrentRate)")
                            .accessibilityAddTraits(.updatesFrequently)

                        // Percent change indicator
                        if let percentChange = historyViewModel.percentChange,
                           let priceChange = historyViewModel.priceChange
                        {
                            percentChangeIndicator(priceChange: priceChange, percentChange: percentChange)
                                .font(.system(.headline, design: .rounded, weight: .medium))
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func percentChangeIndicator(priceChange: Double, percentChange: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: historyViewModel.trendDirection.systemImage)
                .accessibilityHidden(true)

            Text("\(priceChange.formatted(.number.precision(.fractionLength(0 ... 4)).sign(strategy: .never))) (\(abs(percentChange).toStringMax2Decimals)%)")
        }
        .font(.system(.subheadline, design: .rounded, weight: .medium))
        .foregroundColor(historyViewModel.trendDirection.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityChangeLabel(priceChange: priceChange, percentChange: percentChange))
        .accessibilityValue("\(historyViewModel.trendDirection.description) \(abs(percentChange).toStringMax2Decimals) percent")
    }

    private func accessibilityChangeLabel(priceChange: Double, percentChange: Double) -> String {
        let direction = historyViewModel.trendDirection.description
        let changeText = "\(abs(priceChange).formatted(.number.precision(.fractionLength(0 ... 4))))"
        return "Price change: \(direction) \(changeText), \(abs(percentChange).toStringMax2Decimals) percent"
    }
}

// MARK: - Time Range Picker

struct TimeRangePicker: View {
    @Binding var selectedTimeRange: TimeRange
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { timeRange in
                Button(action: {
                    selectedTimeRange = timeRange
                }) {
                    Text(timeRange.rawValue)
                        .font(.system(.headline, design: .rounded, weight: selectedTimeRange == timeRange ? .semibold : .regular))
                        .padding(8)
                        .padding(.horizontal, 2)
                        .foregroundColor(
                            selectedTimeRange == timeRange ?
                                Color.accentColor : Color.secondary
                        )
                }
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        if selectedTimeRange == timeRange {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.2))
                                .matchedGeometryEffect(id: "ACTIVEBUTTON", in: animation)
                        }
                    }
                    .animation(.snappy, value: selectedTimeRange)
                )
                .accessibilityLabel("\(timeRange.accessibilityLabel)")
                .accessibilityHint("Show exchange rate history for \(timeRange.accessibilityLabel)")
                .accessibilityValue(selectedTimeRange == timeRange ? "Selected" : "Not selected")
                .accessibilityInputLabels(timeRange.accessibilityInputLabels)
                .accessibilityAddTraits(selectedTimeRange == timeRange ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
