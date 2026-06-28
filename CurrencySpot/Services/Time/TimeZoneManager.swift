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

    /// Pinned to Gregorian: API dates are ECB calendar dates, and the device
    /// calendar must not leak into them — a Thai-Buddhist or Japanese device
    /// calendar resolves year components era-relative (2568, Reiwa 7), which
    /// would corrupt parseAPIDate and every API date string.
    static let cetCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = cetTimeZone
        return calendar
    }()

    static func parseAPIDate(_ dateString: String) -> Date? {
        guard let (year, month, day) = parseDateComponents(dateString) else {
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

    /// Parses and range-validates a zero-padded `YYYY-MM-DD` string, rejecting any
    /// non-numeric, out-of-range, or non-zero-padded component.
    private static func parseDateComponents(_ dateString: String) -> (year: Int, month: Int, day: Int)? {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              year > 1900, year < 3000,
              month >= 1, month <= 12,
              day >= 1, day <= 31,
              parts[1].count == 2, // Require zero-padded month
              parts[2].count == 2 // Require zero-padded day
        else {
            return nil
        }
        return (year, month, day)
    }

    /// Fixed-format ISO 8601: Gregorian year and ASCII digits regardless of
    /// the device locale or calendar, unlike an unpinned DateFormatter.
    /// Cached because the historical merge and persistence paths format once
    /// per row.
    private static let apiDateFormat = Date.ISO8601FormatStyle(timeZone: cetTimeZone)
        .year().month().day().dateSeparator(.dash)

    static func formatForAPI(_ date: Date) -> String {
        date.formatted(apiDateFormat)
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
