//
//  HistoricalSyncStoreTests.swift
//  CurrencySpotTests
//

import Foundation
import Testing
@testable import CurrencySpot

@Suite("HistoricalSyncStore")
struct HistoricalSyncStoreTests {
    private static func makeDefaults() -> UserDefaults {
        let name = "HistoricalSyncStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("starts empty")
    func startsEmpty() {
        let store = UserDefaultsHistoricalSyncStore(defaults: Self.makeDefaults())
        #expect(store.from == nil)
        #expect(store.through == nil)
        #expect(store.checkedAt == nil)
    }

    @Test("record widens the window monotonically and stamps the check time")
    func recordWidensWindow() {
        let store = UserDefaultsHistoricalSyncStore(defaults: Self.makeDefaults())
        let jan10 = Date(timeIntervalSince1970: 1_000_000)
        let jan20 = Date(timeIntervalSince1970: 2_000_000)
        let jan05 = Date(timeIntervalSince1970: 500_000)
        let t1 = Date(timeIntervalSince1970: 9_000_000)
        let t2 = Date(timeIntervalSince1970: 9_500_000)

        store.record(from: jan10, through: jan20, at: t1)
        #expect(store.from == jan10)
        #expect(store.through == jan20)
        #expect(store.checkedAt == t1)

        // A narrower range must not shrink the window, but still updates checkedAt.
        store.record(from: jan10, through: jan10, at: t2)
        #expect(store.from == jan10)
        #expect(store.through == jan20)
        #expect(store.checkedAt == t2)

        // An older start widens the lower bound.
        store.record(from: jan05, through: jan20, at: t2)
        #expect(store.from == jan05)
    }

    @Test("a disjoint record that reaches further forward replaces the window instead of uniting")
    func disjointForwardRecordReplaces() {
        let store = UserDefaultsHistoricalSyncStore(defaults: Self.makeDefaults())
        let day = 86_400.0
        let t1 = Date(timeIntervalSince1970: 100 * day)
        let t2 = Date(timeIntervalSince1970: 101 * day)
        store.record(from: Date(timeIntervalSince1970: 0), through: Date(timeIntervalSince1970: 10 * day), at: t1)

        // Starts more than a day past the window's end: uniting would claim the
        // unfetched middle as checked. The newer window wins instead.
        let newFrom = Date(timeIntervalSince1970: 20 * day)
        let newThrough = Date(timeIntervalSince1970: 30 * day)
        store.record(from: newFrom, through: newThrough, at: t2)

        #expect(store.from == newFrom)
        #expect(store.through == newThrough)
        #expect(store.checkedAt == t2)
    }

    @Test("a disjoint record behind the window is dropped entirely")
    func disjointBackwardRecordDropped() {
        let store = UserDefaultsHistoricalSyncStore(defaults: Self.makeDefaults())
        let day = 86_400.0
        let t1 = Date(timeIntervalSince1970: 100 * day)
        let from = Date(timeIntervalSince1970: 20 * day)
        let through = Date(timeIntervalSince1970: 30 * day)
        store.record(from: from, through: through, at: t1)

        store.record(
            from: Date(timeIntervalSince1970: 0),
            through: Date(timeIntervalSince1970: 10 * day),
            at: Date(timeIntervalSince1970: 101 * day)
        )

        // The backward range stays unrecorded (it will simply be refetched);
        // checkedAt is untouched so live-edge freshness is not faked.
        #expect(store.from == from)
        #expect(store.through == through)
        #expect(store.checkedAt == t1)
    }

    @Test("an adjacent record (gap of one day) still unions")
    func adjacentRecordUnions() {
        let store = UserDefaultsHistoricalSyncStore(defaults: Self.makeDefaults())
        let day = 86_400.0
        let through = Date(timeIntervalSince1970: 10 * day)
        store.record(from: Date(timeIntervalSince1970: 5 * day), through: through, at: Date(timeIntervalSince1970: 100 * day))

        // Begins exactly one day after the window ends — contiguous coverage.
        store.record(from: Date(timeIntervalSince1970: 11 * day), through: Date(timeIntervalSince1970: 15 * day), at: Date(timeIntervalSince1970: 101 * day))

        #expect(store.from == Date(timeIntervalSince1970: 5 * day))
        #expect(store.through == Date(timeIntervalSince1970: 15 * day))
    }

    @Test("reset clears the window")
    func resetClears() {
        let store = UserDefaultsHistoricalSyncStore(defaults: Self.makeDefaults())
        store.record(from: Date(timeIntervalSince1970: 1), through: Date(timeIntervalSince1970: 2), at: Date(timeIntervalSince1970: 3))

        store.reset()

        #expect(store.from == nil)
        #expect(store.through == nil)
        #expect(store.checkedAt == nil)
    }
}
