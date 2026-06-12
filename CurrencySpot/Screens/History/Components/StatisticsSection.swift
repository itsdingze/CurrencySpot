//
//  StatisticsSection.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/26/25.
//

import SwiftUI

// MARK: - Statistics Section

struct StatisticsSection: View {
    @Environment(HistoryViewModel.self) private var viewModel: HistoryViewModel
    @State private var showVolatilityInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Button(action: toggleHighestPoint) {
                    statCard(
                        label: "Highest",
                        value: viewModel.formattedHighestRate,
                        isToggled: viewModel.showHighestPoint,
                        indicatorColor: .green
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: toggleLowestPoint) {
                    statCard(
                        label: "Lowest",
                        value: viewModel.formattedLowestRate,
                        isToggled: viewModel.showLowestPoint,
                        indicatorColor: .red
                    )
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack(spacing: 0) {
                Button(action: toggleAverageLine) {
                    statCard(
                        label: "Average",
                        value: viewModel.formattedAverageRate,
                        isToggled: viewModel.showAverageLine,
                        indicatorColor: Color.gray
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                volatilityCard(label: "Volatility", value: viewModel.formattedVolatility)
            }
        }
    }

    // MARK: - Private Methods

    private func toggleHighestPoint() {
        withAnimation(.smooth(duration: 0.3)) {
            viewModel.showHighestPoint.toggle()
        }
    }

    private func toggleLowestPoint() {
        withAnimation(.smooth(duration: 0.3)) {
            viewModel.showLowestPoint.toggle()
        }
    }

    private func toggleAverageLine() {
        withAnimation(.smooth(duration: 0.3)) {
            viewModel.showAverageLine.toggle()
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private func statCard(label: String, value: String, isToggled: Bool = false, indicatorColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                if let color = indicatorColor {
                    Circle()
                        .fill(color.opacity(isToggled ? 1.0 : 0.3))
                        .frame(width: 6, height: 6)
                        .animation(.smooth(duration: 0.3), value: isToggled)
                }
            }

            Text(value)
                .font(.system(.headline, design: .rounded).monospacedDigit())
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityValue(accessibilityValueFor(label: label, value: value))
        .accessibilityHint(indicatorColor != nil ? "Tap to \(isToggled ? "hide" : "show") \(label.lowercased()) indicator on chart" : "")
    }

    private func accessibilityValueFor(label: String, value: String) -> String {
        switch label.lowercased() {
        case "highest":
            "Highest exchange rate in the period: \(value)"
        case "lowest":
            "Lowest exchange rate in the period: \(value)"
        case "average":
            "Average exchange rate in the period: \(value)"
        default:
            value
        }
    }

    @ViewBuilder
    private func volatilityCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                showVolatilityInfo = true
            }) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)

                    Image(systemName: "info.circle")
                        .font(.system(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Volatility information")
            .accessibilityHint("Shows explanation of volatility measurement")
            .accessibilityInputLabels(["Volatility info", "What is volatility"])

            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(viewModel.volatilityLevel?.color ?? .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Volatility: \(value)")
        .accessibilityValue("Exchange rate volatility level: \(value)")
        .popover(isPresented: $showVolatilityInfo) {
            VolatilityInfoView()
                .presentationCompactAdaptation(.popover)
        }
    }
}
