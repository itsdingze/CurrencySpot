//
//  HeaderSection.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/26/25.
//

import SwiftUI

struct HeaderSection: View {
    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel
    @Binding var isChartSelectionActive: Bool

    var body: some View {
        VStack(spacing: .sectionGap) {
            currentRateView

            TimeRangePicker(
                selectedTimeRange: historyViewModel.selectedTimeRange,
                onSelect: historyViewModel.selectTimeRange
            )
            .opacity(isChartSelectionActive ? 0 : 1)
        }
    }

    // MARK: - Private Views

    private var currentRateView: some View {
        VStack(spacing: .hairlineGap) {
            HStack(alignment: .firstTextBaseline, spacing: .tightGap) {
                Text(historyViewModel.targetCurrency)
                    .font(.appTitle)
                    .accessibilityLabel("\(historyViewModel.targetCurrency), \(CurrencyUtilities.name(for: historyViewModel.targetCurrency))")

                Text(CurrencyUtilities.name(for: historyViewModel.targetCurrency))
                    .font(.appHeadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                // Try horizontal layout first
                HStack(alignment: .firstTextBaseline, spacing: .tightGap) {
                    Text(historyViewModel.formattedCurrentRate)
                        .font(.appTitle3)
                        .accessibilityLabel("Current rate: \(historyViewModel.formattedCurrentRate)")
                        .accessibilityAddTraits(.updatesFrequently)

                    // Percent change indicator
                    if let percentChange = historyViewModel.percentChange,
                       let priceChange = historyViewModel.priceChange
                    {
                        percentChangeIndicator(priceChange: priceChange, percentChange: percentChange)
                            .font(.appSubheadline.weight(.medium))
                    }

                    Spacer()
                }

                // Fall back to vertical layout when horizontal doesn't fit
                HStack {
                    VStack(alignment: .leading, spacing: .hairlineGap) {
                        Text(historyViewModel.formattedCurrentRate)
                            .font(.appTitle3)
                            .accessibilityLabel("Current rate: \(historyViewModel.formattedCurrentRate)")
                            .accessibilityAddTraits(.updatesFrequently)

                        // Percent change indicator
                        if let percentChange = historyViewModel.percentChange,
                           let priceChange = historyViewModel.priceChange
                        {
                            percentChangeIndicator(priceChange: priceChange, percentChange: percentChange)
                                .font(.appHeadline.weight(.medium))
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func percentChangeIndicator(priceChange: Double, percentChange: Double) -> some View {
        HStack(spacing: .hairlineGap) {
            Image(systemName: historyViewModel.trendDirection.systemImage)
                .accessibilityHidden(true)

            Text("\(priceChange.formatted(.number.precision(.fractionLength(0 ... 4)).sign(strategy: .never))) (\(abs(percentChange).toStringMax2Decimals)%)")
        }
        .font(.appSubheadline.weight(.medium))
        .foregroundStyle(historyViewModel.trendDirection.color)
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
    let selectedTimeRange: TimeRange
    let onSelect: (TimeRange) -> Void
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { timeRange in
                Button(action: {
                    onSelect(timeRange)
                }) {
                    Text(timeRange.rawValue)
                }
                .buttonStyle(SegmentedTabButtonStyle(
                    isSelected: selectedTimeRange == timeRange,
                    namespace: animation
                ))
                .accessibilityLabel(timeRange.displayName)
                .accessibilityHint("Show exchange rate history for \(timeRange.displayName)")
                .accessibilityValue(selectedTimeRange == timeRange ? "Selected" : "Not selected")
                .accessibilityInputLabels(timeRange.accessibilityInputLabels)
                .accessibilityAddTraits(selectedTimeRange == timeRange ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    HeaderSection(isChartSelectionActive: .constant(false))
        .withDependencyContainer(DependencyContainer.preview())
        .padding()
}
#endif

#Preview("TimeRangePicker") {
    @Previewable @State var selectedTimeRange = TimeRange.threeMonths

    TimeRangePicker(
        selectedTimeRange: selectedTimeRange,
        onSelect: { selectedTimeRange = $0 }
    )
    .padding()
}
