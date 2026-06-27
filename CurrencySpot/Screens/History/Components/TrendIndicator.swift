//
//  TrendIndicator.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/18/25.
//

import SwiftUI

struct TrendIndicator: View {
    /// Pre-formatted display text (e.g. "1.23%" or "0.0123"); the caller chooses
    /// percentage vs price so this view only renders.
    let value: String
    let direction: TrendDirection

    var body: some View {
        HStack(spacing: .hairlineGap) {
            Image(systemName: "circle")
                .opacity(0)
                .overlay {
                    Image(systemName: direction.systemImage)
                }
                .accessibilityHidden(true)

            Text(value)
                .lineLimit(1)
                .monospacedDigit()
        }
        .foregroundStyle(direction.color)
        .font(.appSubheadline.weight(.medium))
        .padding(.horizontal, .badgePaddingHorizontal)
        .padding(.vertical, .badgePaddingVertical)
        .frame(minWidth: 80, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: .badgeRadius)
                .fill(direction.color.opacity(0.12))
                .strokeBorder(direction.color.opacity(0.05), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(direction.description) \(value)")
    }
}

#Preview {
    VStack(spacing: 10) {
        TrendIndicator(value: "0.28%", direction: .down)
        TrendIndicator(value: "0.32%", direction: .up)
        TrendIndicator(value: "0.00%", direction: .stable)
    }
    .padding()
}
