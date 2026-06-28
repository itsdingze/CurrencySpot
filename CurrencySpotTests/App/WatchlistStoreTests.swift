//
//  WatchlistStoreTests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("WatchlistStore Tests")
struct WatchlistStoreTests {
    /// A fresh, isolated UserDefaults suite so tests never touch `.standard`.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "WatchlistStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: Seeding

    @Test("seeds from the explicit seed on first launch and persists it")
    func seedsFromExplicitSeed() {
        let defaults = makeDefaults()
        let store = WatchlistStore(userDefaults: defaults, seed: ["EUR", "GBP"])

        #expect(store.codes.elements == ["EUR", "GBP"])
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) == ["EUR", "GBP"])
    }

    @Test("seeds from persisted Settings favorites when no explicit seed is given")
    func seedsFromFavorites() {
        let defaults = makeDefaults()
        defaults.set(["JPY", "CAD"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let store = WatchlistStore(userDefaults: defaults)

        #expect(store.codes.elements == ["JPY", "CAD"])
    }

    @Test("falls back to the out-of-box default when nothing is persisted")
    func seedsFromDefault() {
        let store = WatchlistStore(userDefaults: makeDefaults())

        #expect(store.codes.elements == CurrencyDefaults.favoriteCurrencies)
    }

    @Test("reads the persisted watchlist instead of reseeding")
    func readsPersistedWatchlist() {
        let defaults = makeDefaults()
        defaults.set(["CHF"], forKey: UserDefaultsKeys.historyWatchlist)
        defaults.set(["EUR"], forKey: UserDefaultsKeys.favoriteCurrencies) // must be ignored

        let store = WatchlistStore(userDefaults: defaults, seed: ["GBP"]) // must be ignored

        #expect(store.codes.elements == ["CHF"])
    }

    @Test("stays independent of later favorites changes across a reopen")
    func independentAfterSeed() {
        let defaults = makeDefaults()
        let store = WatchlistStore(userDefaults: defaults, seed: ["EUR"])
        store.add("CHF")

        // Favorites change afterwards — the watchlist must not follow.
        defaults.set(["JPY"], forKey: UserDefaultsKeys.favoriteCurrencies)
        let reopened = WatchlistStore(userDefaults: defaults)

        #expect(reopened.codes.elements == ["EUR", "CHF"])
    }

    // MARK: Mutations

    @Test("add validates, deduplicates, and persists")
    func add() {
        let defaults = makeDefaults()
        let store = WatchlistStore(userDefaults: defaults, seed: [])

        #expect(store.add("eur") == false) // invalid (lowercase)
        #expect(store.add("EUR") == true)
        #expect(store.add("EUR") == false) // duplicate
        #expect(store.codes.elements == ["EUR"])
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) == ["EUR"])
    }

    @Test("remove and contains operate by code identity")
    func removeAndContains() {
        let store = WatchlistStore(userDefaults: makeDefaults(), seed: ["EUR", "GBP"])

        #expect(store.contains("EUR") == true)
        #expect(store.remove("EUR") == true)
        #expect(store.contains("EUR") == false)
        #expect(store.remove("EUR") == false) // already gone
        #expect(store.codes.elements == ["GBP"])
    }

    @Test("toggle adds when absent and removes when present")
    func toggle() {
        let store = WatchlistStore(userDefaults: makeDefaults(), seed: [])

        store.toggle("EUR")
        #expect(store.contains("EUR") == true)

        store.toggle("EUR")
        #expect(store.contains("EUR") == false)
    }

    @Test("reorder applies the displayed order while leaving hidden codes in place")
    func reorder() {
        let store = WatchlistStore(userDefaults: makeDefaults(), seed: ["USD", "EUR", "GBP", "JPY"])

        // USD is the hidden base; reorder only the displayed subset.
        store.reorder(displayedOrder: ["JPY", "EUR", "GBP"])

        #expect(store.codes.elements == ["USD", "JPY", "EUR", "GBP"])
    }

    @Test("reset replaces the whole watchlist with the seed and persists it")
    func reset() {
        let defaults = makeDefaults()
        let store = WatchlistStore(userDefaults: defaults, seed: ["EUR", "GBP"])
        store.add("CHF")

        store.reset(to: CurrencyDefaults.favoriteCurrencies)

        #expect(store.codes.elements == CurrencyDefaults.favoriteCurrencies)
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) == CurrencyDefaults.favoriteCurrencies)
    }
}
