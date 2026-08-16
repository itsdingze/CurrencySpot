import Foundation

nonisolated enum TimeZoneManager {
    static let cetTimeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt

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
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = cetTimeZone

        guard let date = cetCalendar.date(from: components) else {
            return nil
        }

        let createdComponents = cetCalendar.dateComponents([.year, .month, .day], from: date)
        guard createdComponents.year == year,
              createdComponents.month == month,
              createdComponents.day == day
        else {
            return nil
        }

        return date
    }

    private static func parseDateComponents(_ dateString: String) -> (year: Int, month: Int, day: Int)? {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              year > 1900, year < 3000,
              month >= 1, month <= 12,
              day >= 1, day <= 31,
              parts[1].count == 2,
              parts[2].count == 2
        else {
            return nil
        }
        return (year, month, day)
    }

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
