//
//  StatisticsSection.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/26/25.
//

import SwiftUI

// MARK: - Statistics Section

struct StatisticsSection: View {
    @Environment(HistoryViewModel.self) var viewModel: HistoryViewModel
    @State private var showVolatilityInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                statCard(
                    label: "Highest",
                    value: viewModel.formattedHighestRate,
                    isToggled: viewModel.showHighestPoint,
                    indicatorColor: .green
                )
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.3)) {
                        viewModel.showHighestPoint.toggle()
                    }
                }

                Spacer()

                statCard(
                    label: "Lowest",
                    value: viewModel.formattedLowestRate,
                    isToggled: viewModel.showLowestPoint,
                    indicatorColor: .red
                )
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.3)) {
                        viewModel.showLowestPoint.toggle()
                    }
                }
            }

            Divider()

            HStack(spacing: 0) {
                statCard(
                    label: "Average",
                    value: viewModel.formattedAverageRate,
                    isToggled: viewModel.showAverageLine,
                    indicatorColor: Color.gray
                )
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.3)) {
                        viewModel.showAverageLine.toggle()
                    }
                }

                Spacer()

                volatilityCard(label: "Volatility", value: viewModel.formattedVolatility)
            }
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
            .buttonStyle(PlainButtonStyle())
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

// MARK: - Volatility Info View

struct VolatilityInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("What is Volatility?")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("Close volatility information")
                .accessibilityHint("Closes the volatility explanation")
                .accessibilityInputLabels(["Close", "Dismiss", "Done"])
            }

            // Content
            VStack(alignment: .leading, spacing: 12) {
                Text("Volatility measures how much the exchange rate fluctuates over time.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(VolatilityLevel.allCases, id: \.self) { level in
                        volatilityLevelRow(level)
                    }
                }

                Text("Lower volatility means more stable exchange rates, while higher volatility indicates larger price swings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(Color(UIColor.systemBackground))
        .presentationBackground(.regularMaterial)
    }

    @ViewBuilder
    private func volatilityLevelRow(_ level: VolatilityLevel) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(level.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(width: 70, alignment: .leading)

            Text(level.rangeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.displayName) volatility: \(level.rangeDescription)")
    }
}
