//
//  ChartDateFormatting.swift
//  CurrencySpot
//

import Foundation

extension Date {
    /// Format for chart display in local timezone
    var chartDisplay: String {
        TimeZoneManager.formatForChartDisplay(self)
    }
}
