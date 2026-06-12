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
