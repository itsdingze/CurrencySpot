//
//  TimeZoneManager.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/14/25.
//

import Foundation

nonisolated enum TimeZoneManager {
    // "Europe/Paris" is always available; .gmt is an unreachable safe fallback that avoids a force-unwrap.
    static let cetTimeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt

    static var cetCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = cetTimeZone
        return calendar
    }

    static func parseAPIDate(_ dateString: String) -> Date? {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }

        // Validate date components and require zero-padded format
        guard year > 1900, year < 3000,
              month >= 1, month <= 12,
              day >= 1, day <= 31,
              parts[1].count == 2, // Require zero-padded month
              parts[2].count == 2 // Require zero-padded day
        else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0 // Midnight CET
        components.minute = 0
        components.second = 0
        components.timeZone = cetTimeZone

        // Validate that the date actually exists (no Feb 30th, etc.)
        guard let date = cetCalendar.date(from: components) else {
            return nil
        }

        // Double-check that the created date has the same components
        let createdComponents = cetCalendar.dateComponents([.year, .month, .day], from: date)
        guard createdComponents.year == year,
              createdComponents.month == month,
              createdComponents.day == day
        else {
            return nil
        }

        return date
    }

    /// Cached: the historical merge and persistence paths call this once per
    /// row, and DateFormatter allocation dominates them. Safe to share —
    /// NSDateFormatter is documented thread-safe since iOS 7 and this
    /// instance is never mutated after initialization.
    private static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = cetTimeZone
        return formatter
    }()

    static func formatForAPI(_ date: Date) -> String {
        apiFormatter.string(from: date)
    }

    // MARK: - UI Display Methods (Local Timezone)

    static func formatForChartDisplay(_ date: Date) -> String {
        date.formatted(.dateTime
            .month()
            .day()
            .year()
            .locale(Locale.current)
        )
    }

    static func formatLastUpdated(_ date: Date) -> String {
        date.formatted(.dateTime
            .year()
            .month()
            .day()
            .hour()
            .minute()
            .locale(Locale.current)
        )
    }
}
