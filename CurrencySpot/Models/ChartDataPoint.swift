//
//  ChartDataPoint.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import Foundation

/// Represents a single data point for chart visualization
struct ChartDataPoint: Identifiable, Equatable, Sendable {
    let id = UUID()
    let date: Date
    let rate: Double

    static func == (lhs: ChartDataPoint, rhs: ChartDataPoint) -> Bool {
        lhs.date == rhs.date && lhs.rate == rhs.rate
    }
}
