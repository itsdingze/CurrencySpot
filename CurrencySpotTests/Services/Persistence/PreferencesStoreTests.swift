@testable import CurrencySpot
import Foundation
import Testing

@Suite("UserDefaultsPreferencesStore Tests")
struct PreferencesStoreTests {
    private let defaults: UserDefaults
    private let suiteName: String
    private let store: UserDefaultsPreferencesStore

    init() throws {
        suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        store = UserDefaultsPreferencesStore(userDefaults: defaults)
    }

    @Test("an empty store reads the out-of-box defaults")
    func readsOutOfBoxDefaults() {
        #expect(store.accentColor == .cyan)
        #expect(store.appearanceMode == .system)
        #expect(store.defaultBaseCurrency == "USD")
        #expect(store.defaultTargetCurrency == "EUR")
        #expect(store.favoriteCurrencies.elements == CurrencyDefaults.favoriteCurrencies)
        #expect(store.hasSeenOnboarding == false)
        #expect(store.hasSeenChartOnboarding == false)
    }

    @Test("a seeded store reads the persisted values")
    func readsPersistedValues() throws {
        let seededSuiteName = "PreferencesStoreTests.seeded.\(UUID().uuidString)"
        let seeded = try #require(UserDefaults(suiteName: seededSuiteName))
        seeded.removePersistentDomain(forName: seededSuiteName)
        seeded.set("CHF", forKey: UserDefaultsKeys.defaultBaseCurrency)
        seeded.set(["JPY", "CAD"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let seededStore = UserDefaultsPreferencesStore(userDefaults: seeded)

        #expect(seededStore.defaultBaseCurrency == "CHF")
        #expect(seededStore.favoriteCurrencies.elements == ["JPY", "CAD"])
    }

    @Test("a changed preference writes through to the injected defaults")
    func writesThroughOnChange() {
        store.defaultTargetCurrency = "JPY"
        store.appearanceMode = .dark

        #expect(defaults.string(forKey: UserDefaultsKeys.defaultTargetCurrency) == "JPY")
        #expect(defaults.string(forKey: UserDefaultsKeys.appearanceMode) == AppearanceMode.dark.rawValue)
    }

    @Test("addFavorite deduplicates, appends, and persists")
    func addFavorite() {
        #expect(store.addFavorite("USD") == false)
        #expect(store.addFavorite("CHF") == true)
        #expect(store.favoriteCurrencies.last == "CHF")
        #expect(store.addFavorite("CHF") == false)
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies)?.last == "CHF")
    }

    @Test("moveFavorites preserves List reorder semantics")
    func moveFavorites() {
        let original = store.favoriteCurrencies.elements
        var expected = original
        expected.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        store.moveFavorites(from: IndexSet(integer: 0), to: 3)

        #expect(store.favoriteCurrencies.elements == expected)
    }

    @Test("removeFavorite removes by code")
    func removeFavorite() {
        #expect(store.removeFavorite("EUR") == true)
        #expect(store.favoriteCurrencies.contains("EUR") == false)
        #expect(store.removeFavorite("EUR") == false)
    }

    @Test("resetToDefaults restores every value")
    func resetToDefaults() {
        store.accentColor = .pink
        store.defaultBaseCurrency = "GBP"
        store.hasSeenOnboarding = true
        store.addFavorite("CHF")

        store.resetToDefaults()

        #expect(store.accentColor == .cyan)
        #expect(store.defaultBaseCurrency == "USD")
        #expect(store.hasSeenOnboarding == false)
        #expect(store.favoriteCurrencies.elements == CurrencyDefaults.favoriteCurrencies)
    }
}
