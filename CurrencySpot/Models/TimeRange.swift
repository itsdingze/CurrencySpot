//
//  TimeRange.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import Foundation

/// Represents different time ranges for historical data
enum TimeRange: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case fiveYears = "5Y"

    var id: String { rawValue }

    /// Human-readable display name for the time range
    var displayName: String {
        switch self {
        case .oneWeek: "1 Week"
        case .oneMonth: "1 Month"
        case .threeMonths: "3 Months"
        case .sixMonths: "6 Months"
        case .oneYear: "1 Year"
        case .fiveYears: "5 Years"
        }
    }

    /// Accessibility label for the time range
    var accessibilityLabel: String {
        displayName
    }

    /// Accessibility input labels for voice control
    var accessibilityInputLabels: [String] {
        switch self {
        case .oneWeek:
            ["1 week", "one week", "7 days"]
        case .oneMonth:
            ["1 month", "one month", "30 days"]
        case .threeMonths:
            ["3 months", "three months", "quarter"]
        case .sixMonths:
            ["6 months", "six months", "half year"]
        case .oneYear:
            ["1 year", "one year", "12 months"]
        case .fiveYears:
            ["5 years", "five years"]
        }
    }

    /// Calculates the start date for this time range from the given end date
    func startDate(from endDate: Date) -> Date {
        let calendar = TimeZoneManager.cetCalendar

        switch self {
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .fiveYears:
            return calendar.date(byAdding: .year, value: -5, to: endDate) ?? endDate
        }
    }

    /// Date format style for chart X-axis labels
    var chartAxisDateFormat: Date.FormatStyle {
        switch self {
        case .oneWeek, .oneMonth:
            .dateTime.month(.abbreviated).day()
        case .threeMonths, .sixMonths, .oneYear:
            .dateTime.month(.abbreviated)
        case .fiveYears:
            .dateTime.year()
        }
    }
}
