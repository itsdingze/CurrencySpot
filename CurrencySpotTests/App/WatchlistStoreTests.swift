@testable import CurrencySpot
import Foundation
import Testing

@Suite("WatchlistStore Tests")
struct WatchlistStoreTests {
    private let isolatedDefaults = IsolatedDefaults()

    private func makeDefaults() throws -> UserDefaults {
        try isolatedDefaults.make()
    }

    @Test("seeds from the explicit seed on first launch and persists it")
    func seedsFromExplicitSeed() throws {
        let defaults = try makeDefaults()
        let store = WatchlistStore(userDefaults: defaults, seed: ["EUR", "GBP"])

        #expect(store.codes.elements == ["EUR", "GBP"])
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) == ["EUR", "GBP"])
    }

    @Test("seeds from persisted Settings favorites when no explicit seed is given")
    func seedsFromFavorites() throws {
        let defaults = try makeDefaults()
        defaults.set(["JPY", "CAD"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let store = WatchlistStore(userDefaults: defaults)

        #expect(store.codes.elements == ["JPY", "CAD"])
    }

    @Test("falls back to the out-of-box default when nothing is persisted")
    func seedsFromDefault() throws {
        let store = WatchlistStore(userDefaults: try makeDefaults())

        #expect(store.codes.elements == CurrencyDefaults.favoriteCurrencies)
    }

    @Test("reads the persisted watchlist instead of reseeding")
    func readsPersistedWatchlist() throws {
        let defaults = try makeDefaults()
        defaults.set(["CHF"], forKey: UserDefaultsKeys.historyWatchlist)
        defaults.set(["EUR"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let store = WatchlistStore(userDefaults: defaults, seed: ["GBP"])

        #expect(store.codes.elements == ["CHF"])
    }

    @Test("stays independent of later favorites changes across a reopen")
    func independentAfterSeed() throws {
        let defaults = try makeDefaults()
        let store = WatchlistStore(userDefaults: defaults, seed: ["EUR"])
        store.add("CHF")

        defaults.set(["JPY"], forKey: UserDefaultsKeys.favoriteCurrencies)
        let reopened = WatchlistStore(userDefaults: defaults)

        #expect(reopened.codes.elements == ["EUR", "CHF"])
    }

    @Test("add deduplicates and persists")
    func add() throws {
        let defaults = try makeDefaults()
        let store = WatchlistStore(userDefaults: defaults, seed: [])

        #expect(store.add("EUR") == true)
        #expect(store.add("EUR") == false)
        #expect(store.codes.elements == ["EUR"])
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) == ["EUR"])
    }

    @Test("remove and contains operate by code identity")
    func removeAndContains() throws {
        let store = WatchlistStore(userDefaults: try makeDefaults(), seed: ["EUR", "GBP"])

        #expect(store.contains("EUR") == true)
        #expect(store.remove("EUR") == true)
        #expect(store.contains("EUR") == false)
        #expect(store.remove("EUR") == false)
        #expect(store.codes.elements == ["GBP"])
    }

    @Test("toggle adds when absent and removes when present")
    func toggle() throws {
        let store = WatchlistStore(userDefaults: try makeDefaults(), seed: [])

        store.toggle("EUR")
        #expect(store.contains("EUR") == true)

        store.toggle("EUR")
        #expect(store.contains("EUR") == false)
    }

    @Test("reorder applies the displayed order while leaving hidden codes in place")
    func reorder() throws {
        let store = WatchlistStore(userDefaults: try makeDefaults(), seed: ["USD", "EUR", "GBP", "JPY"])

        store.reorder(displayedOrder: ["JPY", "EUR", "GBP"])

        #expect(store.codes.elements == ["USD", "JPY", "EUR", "GBP"])
    }

    @Test("reset replaces the whole watchlist with the seed and persists it")
    func reset() throws {
        let defaults = try makeDefaults()
        let store = WatchlistStore(userDefaults: defaults, seed: ["EUR", "GBP"])
        store.add("CHF")

        store.reset(to: CurrencyDefaults.favoriteCurrencies)

        #expect(store.codes.elements == CurrencyDefaults.favoriteCurrencies)
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) == CurrencyDefaults.favoriteCurrencies.map(\.rawValue))
    }
}
