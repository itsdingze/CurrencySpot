//
//  TimeZoneManager.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/14/25.
//

import Foundation

enum TimeZoneManager {
    static let cetTimeZone = TimeZone(identifier: "Europe/Paris")!

    static var cetCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = cetTimeZone
        return calendar
    }

    // ✅ Parse API date strings as CET dates
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

    // ✅ Format dates for API (always CET-based) using FormatStyle
    static func formatForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = cetTimeZone
        return formatter.string(from: date)
    }

    // ✅ Create CET date from components
    static func createCETDate(year: Int, month: Int, day: Int) -> Date? {
        // Validate date components
        guard year > 1900, year < 3000,
              month >= 1, month <= 12,
              day >= 1, day <= 31
        else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
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

    // ✅ Add days in CET context
    static func addDays(_ days: Int, to date: Date) -> Date? {
        cetCalendar.date(byAdding: .day, value: days, to: date)
    }

    // ✅ Calculate days between dates in CET
    static func daysBetween(_ startDate: Date, _ endDate: Date) -> Int {
        cetCalendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    // MARK: - UI Display Methods (Local Timezone)

    // ✅ Format CET dates for UI display in user's local timezone
    static func formatForDisplay(_ date: Date, style _: Date.FormatStyle.DateStyle = .abbreviated) -> String {
        date.formatted(.dateTime
            .month(.abbreviated)
            .day()
            .year()
            .locale(Locale.current)
        )
    }

    // ✅ Format for chart display with abbreviated month/day
    static func formatForChartDisplay(_ date: Date) -> String {
        date.formatted(.dateTime
            .month()
            .day()
            .year()
            .locale(Locale.current)
        )
    }

    // ✅ Format for detailed display with full date
    static func formatForDetailDisplay(_ date: Date) -> String {
        date.formatted(.dateTime
            .weekday(.wide)
            .month(.wide)
            .day()
            .year()
            .locale(Locale.current)
        )
    }

    // ✅ Format for time display (hours and minutes)
    static func formatTimeDisplay(_ date: Date) -> String {
        date.formatted(.dateTime
            .hour()
            .minute()
            .locale(Locale.current)
        )
    }

    // ✅ Format for last updated timestamp
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
