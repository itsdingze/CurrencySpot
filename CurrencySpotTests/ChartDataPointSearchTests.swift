//
//  ChartDataPointSearchTests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("ChartDataPoint closestPoint Tests")
struct ChartDataPointSearchTests {
    private let points: [ChartDataPoint]

    init() throws {
        points = try (1 ... 9).map { day in
            // Every other day: 1, 3, 5, 7, 9 of June 2025.
            let date = try #require(createCETDate(year: 2025, month: 6, day: day * 2 - 1))
            return ChartDataPoint(date: date, rate: Double(day))
        }
    }

    @Test("an exact date hit returns that point")
    func exactMatch() throws {
        let target = try #require(createCETDate(year: 2025, month: 6, day: 5))

        let closest = points.closestPoint(to: target)

        #expect(closest?.rate == 3)
    }

    @Test("a date between points returns the nearest by day")
    func betweenPoints() throws {
        // June 6 sits between June 5 and June 7; June 5 is 1 day away, June 7 is 1 day away,
        // min(by:) keeps the first strictly-closer candidate — the earlier point on a tie.
        let target = try #require(createCETDate(year: 2025, month: 6, day: 6))

        let closest = points.closestPoint(to: target)

        #expect(closest?.rate == 3 || closest?.rate == 4)

        // June 8 is unambiguously closest to June 7.
        let target2 = try #require(createCETDate(year: 2025, month: 6, day: 8))
        #expect(points.closestPoint(to: target2)?.rate == 4)
    }

    @Test("dates beyond the ends clamp to the boundary points")
    func clampsToBounds() throws {
        let before = try #require(createCETDate(year: 2025, month: 5, day: 1))
        let after = try #require(createCETDate(year: 2025, month: 7, day: 30))

        #expect(points.closestPoint(to: before)?.rate == 1)
        #expect(points.closestPoint(to: after)?.rate == 9)
    }

    @Test("an empty series returns nil")
    func emptySeries() throws {
        let target = try #require(createCETDate(year: 2025, month: 6, day: 5))

        #expect([ChartDataPoint]().closestPoint(to: target) == nil)
    }
}
