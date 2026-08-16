import Foundation

nonisolated struct ChartDataPoint: Identifiable, Equatable, Sendable {
    let date: Date
    let rate: Double

    var id: Date { date }
}

// MARK: - Nearest-Point Lookup

nonisolated extension RandomAccessCollection<ChartDataPoint> where Index == Int {
    func closestPoint(to date: Date, calendar: Calendar = TimeZoneManager.cetCalendar) -> ChartDataPoint? {
        guard !isEmpty else { return nil }

        let targetDay = calendar.startOfDay(for: date)

        var left = startIndex
        var right = endIndex

        while left < right {
            let mid = left + (right - left) / 2
            let midDay = calendar.startOfDay(for: self[mid].date)

            if midDay < targetDay {
                left = mid + 1
            } else {
                right = mid
            }
        }

        var candidates: [ChartDataPoint] = []
        if left > startIndex {
            candidates.append(self[left - 1])
        }
        if left < endIndex {
            candidates.append(self[left])
        }

        return candidates.min { first, second in
            let firstDay = calendar.startOfDay(for: first.date)
            let secondDay = calendar.startOfDay(for: second.date)
            return abs(firstDay.timeIntervalSince(targetDay)) < abs(secondDay.timeIntervalSince(targetDay))
        }
    }
}
