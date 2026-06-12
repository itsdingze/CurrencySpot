//
//  SampleChartData.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/27/25.
//

import Foundation

enum SampleChartData {
    static let points: [SampleDataPoint] = [
        SampleDataPoint(date: Date().addingTimeInterval(-6 * 24 * 3600), rate: 1.15),
        SampleDataPoint(date: Date().addingTimeInterval(-5 * 24 * 3600), rate: 1.16),
        SampleDataPoint(date: Date().addingTimeInterval(-4 * 24 * 3600), rate: 1.165),
        SampleDataPoint(date: Date().addingTimeInterval(-3 * 24 * 3600), rate: 1.18),
        SampleDataPoint(date: Date().addingTimeInterval(-2 * 24 * 3600), rate: 1.15),
        SampleDataPoint(date: Date().addingTimeInterval(-1 * 24 * 3600), rate: 1.14),
        SampleDataPoint(date: Date(), rate: 1.15),
    ]

    private static let _rates: [Double] = points.map(\.rate)

    static let highestPoint: SampleDataPoint? = points.max { $0.rate < $1.rate }
    static let lowestPoint: SampleDataPoint? = points.min { $0.rate < $1.rate }
    static let averageRate: Double = _rates.reduce(0, +) / Double(_rates.count)
    static let minimumRate: Double = _rates.min() ?? 0
    static let maximumRate: Double = _rates.max() ?? 1

    static let chartYDomain: ClosedRange<Double> = (minimumRate * 0.99) ... (maximumRate * 1.01)
}

struct SampleDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rate: Double
}
