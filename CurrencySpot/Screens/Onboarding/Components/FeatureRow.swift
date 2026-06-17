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
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 32

    var body: some View {
        HStack(alignment: .center, spacing: .sectionGap) {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: .tightGap) {
                Text(title)
                    .font(.appHeadline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .combine)
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
