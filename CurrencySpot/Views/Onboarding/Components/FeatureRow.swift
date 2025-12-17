//
//  FeatureRow.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/27/25.
//

import SwiftUI

struct FeatureRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "circle")
                .opacity(0)
                .frame(width: 40)
                .overlay(
                    Image(systemName: symbol)
                        .font(.title)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 45)
                        .accessibilityHidden(true)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        FeatureRow(
            symbol: "hand.tap",
            title: "Toggle Chart Elements",
            subtitle: "Tap on statistics to show or hide chart indicators."
        )

        FeatureRow(
            symbol: "chart.line.flattrend.xyaxis",
            title: "View Average Line",
            subtitle: "Tap 'Average' to display the average rate line on the chart."
        )

        FeatureRow(
            symbol: "hand.point.up.left",
            title: "Touch to Select",
            subtitle: "Touch and hold on the chart to see detailed information for any date."
        )

        FeatureRow(
            symbol: "arrow.left.and.right",
            title: "Drag to Explore",
            subtitle: "Move your finger across the chart to explore different data points."
        )
    }
    .padding()
}
