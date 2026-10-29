import Foundation

nonisolated enum RatePublishSchedule {
    private static let publishHour = 16
    private static let publishMinute = 15
    private static let weekendWeekdays: Set = [1, 7]
    private static let retryInterval: TimeInterval = 60 * 60
    private static let calendar = CETCalendar.calendar

    static func nextRefresh(after now: Date, latestRateDay: Date?) -> Date {
        guard let latestRateDay, !isMissingPublish(asOf: now, latestRateDay: latestRateDay) else {
            return now.addingTimeInterval(retryInterval)
        }
        return publishTimes(from: now, by: 1).first { $0 > now } ?? now.addingTimeInterval(retryInterval)
    }

    private static func isMissingPublish(asOf now: Date, latestRateDay: Date) -> Bool {
        guard let lastPublish = publishTimes(from: now, by: -1).first(where: { $0 <= now }) else { return false }
        return calendar.startOfDay(for: latestRateDay) < calendar.startOfDay(for: lastPublish)
    }

    private static func publishTimes(from now: Date, by step: Int) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0 ... 7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset * step, to: today),
                  !weekendWeekdays.contains(calendar.component(.weekday, from: day))
            else { return nil }
            return calendar.date(bySettingHour: publishHour, minute: publishMinute, second: 0, of: day)
        }
    }
}
