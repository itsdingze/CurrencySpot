//
//  MiniChart.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/18/25.
//

import Charts
import SwiftUI

struct MiniChart: View {
    let trendDataValue: TrendDataValue

    private let data: [Double]
    private let direction: TrendDirection
    private let chartWidth: CGFloat = 80
    private let chartHeight: CGFloat = 48
    private let endpointSize: CGFloat = 6
    private let innerPointSize: CGFloat = 4
    private let lineWidth: CGFloat = 1.5
    private let tension: Double = 0.8
    private let domainPadding: Double = 0.01

    init(trendDataValue: TrendDataValue) {
        self.trendDataValue = trendDataValue
        data = trendDataValue.miniChartData
        direction = trendDataValue.direction
    }

    private var chartYDomain: ClosedRange<Double> {
        guard !data.isEmpty else {
            return 0 ... 1
        }

        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 1
        let padding = domainPadding

        return (minValue * (1 - padding)) ... (maxValue * (1 + padding))
    }

    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                chartLineMark(at: index, value: value)
                chartAreaMark(at: index, value: value)
            }

            endpointMarker
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: chartYDomain)
        .frame(width: chartWidth, height: chartHeight)
    }

    // MARK: - Private Chart Content

    private func chartLineMark(at index: Int, value: Double) -> some ChartContent {
        LineMark(
            x: .value("Day", index),
            y: .value("Rate", value)
        )
        .interpolationMethod(.cardinal(tension: tension))
        .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        .foregroundStyle(direction.color)
    }

    private func chartAreaMark(at index: Int, value: Double) -> some ChartContent {
        AreaMark(
            x: .value("Day", index),
            yStart: .value("Rate", value),
            yEnd: .value("Rate", chartYDomain.lowerBound)
        )
        .interpolationMethod(.cardinal(tension: tension))
        .foregroundStyle(areaGradient)
    }

    @ChartContentBuilder
    private var endpointMarker: some ChartContent {
        if let lastIndex = data.indices.last,
           let lastValue = data.last
        {
            PointMark(
                x: .value("Day", lastIndex),
                y: .value("Rate", lastValue)
            )
            .symbol {
                endpointSymbol
            }
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var endpointSymbol: some View {
        ZStack {
            Circle()
                .fill(Color.background)
                .frame(width: endpointSize, height: endpointSize)
            Circle()
                .fill(direction.color)
                .frame(width: innerPointSize, height: innerPointSize)
        }
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                direction.color.opacity(0.1),
                direction.color.opacity(0),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    VStack(spacing: 200) {
        // Upward trend
        MiniChart(trendDataValue: TrendDataValue(
            currencyCode: "AUD",
            weeklyChange: 2.3,
            miniChartData: [1.52, 1.53, 1.54, 1.55, 1.56, 1.57, 1.55]
        ))

        // Downward trend
        MiniChart(trendDataValue: TrendDataValue(
            currencyCode: "AUD",
            weeklyChange: -1.2,
            miniChartData: [1.52, 1.53, 1.54, 1.55, 1.56, 1.52, 1.55]
        ))

        // Stable trend
        MiniChart(trendDataValue: TrendDataValue(
            currencyCode: "AUD",
            weeklyChange: 0.08,
            miniChartData: [1.52, 1.53, 1.54, 1.55, 1.56, 1.55, 1.55]
        ))
    }
}
