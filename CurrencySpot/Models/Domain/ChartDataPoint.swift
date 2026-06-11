//
//  ChartDataPoint.swift
//  CurrencySpot
//

import Foundation

/// Represents a single data point for chart visualization.
/// Identity is the date: each series carries at most one point per date.
struct ChartDataPoint: Identifiable, Equatable, Sendable {
    let date: Date
    let rate: Double

    var id: Date { date }
}
