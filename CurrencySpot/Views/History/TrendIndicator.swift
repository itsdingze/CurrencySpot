//
//  TrendIndicator.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/18/25.
//

import SwiftUI

struct TrendIndicator: View {
    let change: Double
    let direction: TrendDirection

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle")
                .opacity(0)
                .overlay {
                    Image(systemName: direction.systemImage)
                }

            Text(abs(change).formatted(.number.precision(.fractionLength(2))) + "%")
                .lineLimit(1)
                .monospacedDigit()
        }
        .foregroundStyle(direction.color)
        .font(.system(.subheadline, design: .rounded, weight: .medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(minWidth: 80, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(direction.color.opacity(0.12))
                .stroke(direction.color.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 10) {
        TrendIndicator(change: 0.28, direction: .down)
        TrendIndicator(change: 0.32, direction: .up)
        TrendIndicator(change: 0.00, direction: .stable)
    }
    .padding()
}
