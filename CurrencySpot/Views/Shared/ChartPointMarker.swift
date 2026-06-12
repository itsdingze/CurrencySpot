//
//  ChartPointMarker.swift
//  CurrencySpot
//

import SwiftUI

/// The two-circle point marker used across all charts: a background dot with a
/// colored dot inset. Sizes are parameterized to preserve each call site's
/// current values until the design phase unifies them.
struct ChartPointMarker: View {
    let color: Color
    var outerSize: CGFloat = 8
    var innerSize: CGFloat = 6
    var backgroundColor: Color = Color(.systemBackground)

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: outerSize, height: outerSize)

            Circle()
                .fill(color)
                .frame(width: innerSize, height: innerSize)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        ChartPointMarker(color: .green)
        ChartPointMarker(color: .red)
        ChartPointMarker(color: .accentColor, outerSize: 14, innerSize: 10)
    }
    .padding()
}
