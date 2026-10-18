@testable import CurrencySpot
import Foundation
import IdentifiedCollections
import Testing

@Suite("CurrencyCodeListStore Tests")
struct CurrencyCodeListStoreTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let key = "CurrencyCodeListStoreTests.codes"

    private func makeDefaults() throws -> UserDefaults {
        try isolatedDefaults.make()
    }

    // MARK: - Seeding

    @Test("seeds from the seed on first launch and persists it under its key")
    func seedsAndPersistsOnFirstLaunch() throws {
        let defaults = try makeDefaults()

        let store = CurrencyCodeListStore(defaults: defaults, key: key, seed: ["EUR", "GBP"])

        #expect(store.codes.elements == ["EUR", "GBP"])
        #expect(defaults.stringArray(forKey: key) == ["EUR", "GBP"])
    }

    @Test("a persisted list wins over the seed")
    func persistedListWinsOverSeed() throws {
        let defaults = try makeDefaults()
        defaults.set(["CHF"], forKey: key)

        let store = CurrencyCodeListStore(defaults: defaults, key: key, seed: ["GBP"])

        #expect(store.codes.elements == ["CHF"])
    }

    @Test("a persisted empty list wins over the seed")
    func persistedEmptyListWinsOverSeed() throws {
        let defaults = try makeDefaults()
        defaults.set([String](), forKey: key)

        let store = CurrencyCodeListStore(defaults: defaults, key: key, seed: ["EUR"])

        #expect(store.codes.isEmpty)
    }

    @Test("duplicates in the persisted list and in the seed collapse to their first occurrence")
    func deduplicatesPersistedAndSeededCodes() throws {
        let defaults = try makeDefaults()
        defaults.set(["EUR", "GBP", "EUR"], forKey: key)

        let persisted = CurrencyCodeListStore(defaults: defaults, key: key, seed: [])
        let seeded = CurrencyCodeListStore(defaults: try makeDefaults(), key: key, seed: ["USD", "JPY", "USD"])

        #expect(persisted.codes.elements == ["EUR", "GBP"])
        #expect(seeded.codes.elements == ["USD", "JPY"])
    }

    @Test("changes survive a reopen")
    func roundTripsAcrossAReopen() throws {
        let defaults = try makeDefaults()
        let store = CurrencyCodeListStore(defaults: defaults, key: key, seed: ["EUR"])
        store.add("CHF")

        let reopened = CurrencyCodeListStore(defaults: defaults, key: key, seed: ["JPY"])

        #expect(reopened.codes.elements == ["EUR", "CHF"])
    }

    @Test("stores under different keys never see each other's codes")
    func keysAreIsolated() throws {
        let defaults = try makeDefaults()
        let first = CurrencyCodeListStore(defaults: defaults, key: "first", seed: ["EUR"])
        let second = CurrencyCodeListStore(defaults: defaults, key: "second", seed: ["GBP"])

        first.add("CHF")
        second.remove("GBP")

        #expect(CurrencyCodeListStore(defaults: defaults, key: "first", seed: []).codes.elements == ["EUR", "CHF"])
        #expect(CurrencyCodeListStore(defaults: defaults, key: "second", seed: ["NZD"]).codes.isEmpty)
    }

    // MARK: - Mutations

    @Test("add deduplicates and persists")
    func add() throws {
        let defaults = try makeDefaults()
        let store = CurrencyCodeListStore(defaults: defaults, key: key, seed: [])

        #expect(store.add("EUR") == true)
        #expect(store.add("EUR") == false)
        #expect(store.codes.elements == ["EUR"])
        #expect(defaults.stringArray(forKey: key) == ["EUR"])
    }

    @Test("remove and contains operate by code identity")
    func removeAndContains() throws {
        let defaults = try makeDefaults()
        let store = CurrencyCodeListStore(defaults: defaults, key: key, seed: ["EUR", "GBP"])

        #expect(store.contains("EUR") == true)
        #expect(store.remove("EUR") == true)
        #expect(store.contains("EUR") == false)
        #expect(store.remove("EUR") == false)
        #expect(store.codes.elements == ["GBP"])
        #expect(defaults.stringArray(forKey: key) == ["GBP"])
    }

    @Test("toggle adds when absent and removes when present")
    func toggle() throws {
        let store = CurrencyCodeListStore(defaults: try makeDefaults(), key: key, seed: [])

        store.toggle("EUR")
        #expect(store.contains("EUR") == true)

        store.toggle("EUR")
        #expect(store.contains("EUR") == false)
    }

    @Test("reorder applies the displayed order while leaving hidden codes in place")
    func reorder() throws {
        let defaults = try makeDefaults()
        let store = CurrencyCodeListStore(defaults: defaults, key: key, seed: ["USD", "EUR", "GBP", "JPY"])

        store.reorder(displayedOrder: ["JPY", "EUR", "GBP"])

        #expect(store.codes.elements == ["USD", "JPY", "EUR", "GBP"])
        #expect(defaults.stringArray(forKey: key) == ["USD", "JPY", "EUR", "GBP"])
    }

    @Test("move follows List reorder semantics and persists")
    func move() throws {
        let defaults = try makeDefaults()
        let store = CurrencyCodeListStore(defaults: defaults, key: key, seed: ["USD", "EUR", "GBP", "JPY"])

        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(store.codes.elements == ["EUR", "GBP", "USD", "JPY"])
        #expect(defaults.stringArray(forKey: key) == ["EUR", "GBP", "USD", "JPY"])
    }

    @Test("reset replaces the whole list and persists it")
    func reset() throws {
        let defaults = try makeDefaults()
        let store = CurrencyCodeListStore(defaults: defaults, key: key, seed: ["EUR", "GBP"])
        store.add("CHF")

        store.reset(to: ["JPY", "CAD", "JPY"])

        #expect(store.codes.elements == ["JPY", "CAD"])
        #expect(defaults.stringArray(forKey: key) == ["JPY", "CAD"])
    }

    // MARK: - Favorites and Watchlist

    @Test("favorites start from the out-of-box defaults under the favorites key")
    func favoritesSeedFromDefaults() throws {
        let defaults = try makeDefaults()

        let favorites = CurrencyCodeListStore.favorites(in: defaults)

        #expect(favorites.codes.elements == CurrencyDefaults.favoriteCurrencies)
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies) == CurrencyDefaults.favoriteCurrencies.map(\.rawValue))
    }

    @Test("favorites read what earlier versions persisted under the favorites key")
    func favoritesReadPersistedFavorites() throws {
        let defaults = try makeDefaults()
        defaults.set(["JPY", "CAD"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let favorites = CurrencyCodeListStore.favorites(in: defaults)

        #expect(favorites.codes.elements == ["JPY", "CAD"])
    }

    @Test("a first-launch watchlist seeds from the persisted favorites under the watchlist key")
    func watchlistSeedsFromPersistedFavorites() throws {
        let defaults = try makeDefaults()
        defaults.set(["JPY", "CAD"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let watchlist = CurrencyCodeListStore.watchlist(
            in: defaults,
            seededFrom: CurrencyCodeListStore.favorites(in: defaults)
        )

        #expect(watchlist.codes.elements == ["JPY", "CAD"])
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) == ["JPY", "CAD"])
    }

    @Test("a first-launch watchlist falls back to the default favorites when nothing is persisted")
    func watchlistSeedsFromDefaultFavorites() throws {
        let defaults = try makeDefaults()

        let watchlist = CurrencyCodeListStore.watchlist(
            in: defaults,
            seededFrom: CurrencyCodeListStore.favorites(in: defaults)
        )

        #expect(watchlist.codes.elements == CurrencyDefaults.favoriteCurrencies)
    }

    @Test("a persisted watchlist wins over the favorites seed")
    func watchlistReadsPersistedWatchlist() throws {
        let defaults = try makeDefaults()
        defaults.set(["CHF"], forKey: UserDefaultsKeys.historyWatchlist)
        defaults.set(["EUR"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let watchlist = CurrencyCodeListStore.watchlist(
            in: defaults,
            seededFrom: CurrencyCodeListStore.favorites(in: defaults)
        )

        #expect(watchlist.codes.elements == ["CHF"])
    }

    @Test("the watchlist stays independent of later favorites changes across a reopen")
    func watchlistIndependentAfterSeed() throws {
        let defaults = try makeDefaults()
        defaults.set(["EUR"], forKey: UserDefaultsKeys.favoriteCurrencies)
        let favorites = CurrencyCodeListStore.favorites(in: defaults)
        let watchlist = CurrencyCodeListStore.watchlist(in: defaults, seededFrom: favorites)
        watchlist.add("CHF")

        favorites.add("JPY")
        let reopened = CurrencyCodeListStore.watchlist(
            in: defaults,
            seededFrom: CurrencyCodeListStore.favorites(in: defaults)
        )

        #expect(reopened.codes.elements == ["EUR", "CHF"])
    }
}
