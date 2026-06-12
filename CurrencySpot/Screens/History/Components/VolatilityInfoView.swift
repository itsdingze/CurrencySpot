//
//  VolatilityInfoView.swift
//  CurrencySpot
//

import SwiftUI

/// Popover explaining the volatility metric and its qualitative levels.
struct VolatilityInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: .sectionGap) {
            // Header
            HStack {
                Text("What is Volatility?")
                    .font(.appHeadline)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appTitle2)
                        .foregroundStyle(.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("Close volatility information")
                .accessibilityHint("Closes the volatility explanation")
                .accessibilityInputLabels(["Close", "Dismiss", "Done"])
            }

            // Content
            VStack(alignment: .leading, spacing: .elementGap) {
                Text("Volatility measures how much the exchange rate fluctuates over time.")
                    .font(.appSubheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: .tightGap) {
                    ForEach(VolatilityLevel.allCases, id: \.self) { level in
                        volatilityLevelRow(level)
                    }
                }

                Text("Lower volatility means more stable exchange rates, while higher volatility indicates larger price swings.")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.cardPadding)
        .frame(idealWidth: 320, maxWidth: 400)
        .background(Color(UIColor.systemBackground))
        .presentationBackground(.regularMaterial)
    }

    @ViewBuilder
    private func volatilityLevelRow(_ level: VolatilityLevel) -> some View {
        HStack(spacing: .tightGap) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(level.displayName)
                .font(.appCaption.weight(.medium))
                .foregroundStyle(.primary)
                .frame(minWidth: 70, alignment: .leading)

            Text(level.rangeDescription)
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.displayName) volatility: \(level.rangeDescription)")
    }
}

#Preview {
    VolatilityInfoView()
}
