import Foundation

nonisolated enum CETCalendar {
    static let timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    private static let dayStringFormat = Date.ISO8601FormatStyle(timeZone: timeZone)
        .year().month().day().dateSeparator(.dash)

    static func dayString(for date: Date) -> String {
        date.formatted(dayStringFormat)
    }

    static func date(fromDayString dayString: String) -> Date? {
        guard let (year, month, day) = dayComponents(of: dayString) else {
            return nil
        }

        let components = DateComponents(timeZone: timeZone, year: year, month: month, day: day, hour: 0, minute: 0, second: 0)
        guard let date = calendar.date(from: components) else {
            return nil
        }

        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else {
            return nil
        }

        return date
    }

    private static func dayComponents(of dayString: String) -> (year: Int, month: Int, day: Int)? {
        let parts = dayString.split(separator: "-")
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
}
