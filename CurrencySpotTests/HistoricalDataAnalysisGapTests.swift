//
//  HistoricalDataAnalysisGapTests.swift
//  CurrencySpotTests
//

import Foundation
import Testing
@testable import CurrencySpot

@Suite("HistoricalDataAnalysisUseCase — sync-coverage fetch gate")
struct HistoricalDataAnalysisGapTests {
    private static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        TimeZoneManager.createCETDate(year: y, month: m, day: d)!
    }

    private static func useCase(from: Date?, through: Date?, checkedAt: Date?) -> HistoricalDataAnalysisUseCase {
        HistoricalDataAnalysisUseCase(
            syncStore: MockHistoricalSyncStore(from: from, through: through, checkedAt: checkedAt)
        )
    }

    @Test("never synced → always fetch")
    func neverSynced() {
        let uc = Self.useCase(from: nil, through: nil, checkedAt: nil)
        let d = Self.day(2026, 6, 3)
        #expect(uc.shouldFetchGap(gapStart: d, gapEnd: d, now: Self.day(2026, 6, 10)) == true)
    }

    @Test("gap older than the covered window → fetch (back-fill)")
    func extendsBeforeCoverage() {
        let uc = Self.useCase(from: Self.day(2026, 6, 1), through: Self.day(2026, 6, 7), checkedAt: Self.day(2026, 6, 7))
        // user widened the time range backward
        #expect(uc.shouldFetchGap(gapStart: Self.day(2026, 5, 20), gapEnd: Self.day(2026, 5, 31), now: Self.day(2026, 6, 10)) == true)
    }

    @Test("gap newer than the covered window → fetch")
    func extendsPastCoverage() {
        let uc = Self.useCase(from: Self.day(2026, 6, 1), through: Self.day(2026, 6, 7), checkedAt: Self.day(2026, 6, 7))
        #expect(uc.shouldFetchGap(gapStart: Self.day(2026, 6, 8), gapEnd: Self.day(2026, 6, 9), now: Self.day(2026, 6, 9)) == true)
    }

    @Test("interior day already checked and empty → never refetch")
    func interiorKnownEmpty() {
        let uc = Self.useCase(from: Self.day(2026, 6, 1), through: Self.day(2026, 6, 7), checkedAt: Self.day(2026, 6, 7))
        let now = Self.day(2026, 6, 10).addingTimeInterval(12 * 3600)
        #expect(uc.shouldFetchGap(gapStart: Self.day(2026, 6, 3), gapEnd: Self.day(2026, 6, 3), now: now) == false)
    }

    @Test("covered through an old day (not today) → never refetch even if stale")
    func coveredThroughOldDay() {
        // through == jun6, but today is jun10 → the gap is entirely in the past, known-empty
        let uc = Self.useCase(from: Self.day(2026, 6, 1), through: Self.day(2026, 6, 6), checkedAt: Self.day(2026, 6, 6))
        let now = Self.day(2026, 6, 10).addingTimeInterval(12 * 3600)
        #expect(uc.shouldFetchGap(gapStart: Self.day(2026, 6, 6), gapEnd: Self.day(2026, 6, 6), now: now) == false)
    }

    @Test("today's edge, last checked >6h ago → refetch to catch late data")
    func liveEdgeStale() {
        let today = Self.day(2026, 6, 7)
        let now = today.addingTimeInterval(13 * 3600)
        let uc = Self.useCase(from: Self.day(2026, 6, 1), through: today, checkedAt: now.addingTimeInterval(-7 * 3600))
        #expect(uc.shouldFetchGap(gapStart: today, gapEnd: today, now: now) == true)
    }

    @Test("today's edge, checked <6h ago → skip (loop broken)")
    func liveEdgeFresh() {
        let today = Self.day(2026, 6, 7)
        let now = today.addingTimeInterval(13 * 3600)
        let uc = Self.useCase(from: Self.day(2026, 6, 1), through: today, checkedAt: now.addingTimeInterval(-1 * 3600))
        #expect(uc.shouldFetchGap(gapStart: today, gapEnd: today, now: now) == false)
    }

    @Test("today's edge, checked exactly 6h ago → refetch (>= boundary)")
    func liveEdgeAtTTLBoundary() {
        let today = Self.day(2026, 6, 7)
        let now = today.addingTimeInterval(13 * 3600)
        let uc = Self.useCase(from: Self.day(2026, 6, 1), through: today, checkedAt: now.addingTimeInterval(-6 * 3600))
        #expect(uc.shouldFetchGap(gapStart: today, gapEnd: today, now: now) == true)
    }

    @Test("recordSync forwards the fetched range to the store")
    func recordSyncForwards() {
        let mock = MockHistoricalSyncStore()
        let uc = HistoricalDataAnalysisUseCase(syncStore: mock)
        let from = Self.day(2026, 6, 1)
        let through = Self.day(2026, 6, 7)
        let now = Self.day(2026, 6, 7).addingTimeInterval(9 * 3600)

        uc.recordSync(from: from, through: through, now: now)

        #expect(mock.recordCallCount == 1)
        #expect(mock.from == from)
        #expect(mock.through == through)
        #expect(mock.checkedAt == now)
    }
}
