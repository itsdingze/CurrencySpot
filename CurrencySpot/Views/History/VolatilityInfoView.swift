//
//  VolatilityInfoView.swift
//  CurrencySpot
//

import SwiftUI

/// Popover explaining the volatility metric and its qualitative levels.
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

#Preview {
    VolatilityInfoView()
}
