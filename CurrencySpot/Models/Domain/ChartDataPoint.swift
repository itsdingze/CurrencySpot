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

// MARK: - Nearest-Point Lookup

extension RandomAccessCollection<ChartDataPoint> where Index == Int {
    /// Day-granularity nearest point to `date`, found by binary search.
    /// Assumes the collection is sorted ascending by date (chart series are).
    func closestPoint(to date: Date, calendar: Calendar = TimeZoneManager.cetCalendar) -> ChartDataPoint? {
        guard !isEmpty else { return nil }

        let targetDay = calendar.startOfDay(for: date)

        // Binary search for the insertion point using normalized dates.
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

        // Check candidates around the insertion point.
        var candidates: [ChartDataPoint] = []
        if left > startIndex {
            candidates.append(self[left - 1])
        }
        if left < endIndex {
            candidates.append(self[left])
        }

        // Compare using day-level granularity.
        return candidates.min { first, second in
            let firstDay = calendar.startOfDay(for: first.date)
            let secondDay = calendar.startOfDay(for: second.date)
            return abs(firstDay.timeIntervalSince(targetDay)) < abs(secondDay.timeIntervalSince(targetDay))
        }
    }
}
