@testable import CurrencySpot
import Foundation
import Testing

@Suite("UserDefaultsPreferencesStore Tests")
struct PreferencesStoreTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let defaults: UserDefaults
    private let store: UserDefaultsPreferencesStore

    init() throws {
        defaults = try isolatedDefaults.make()
        store = UserDefaultsPreferencesStore(userDefaults: defaults)
    }

    @Test("an empty store reads the out-of-box defaults")
    func readsOutOfBoxDefaults() {
        #expect(store.accentColor == .cyan)
        #expect(store.appearanceMode == .system)
        #expect(store.defaultBaseCurrency == "USD")
        #expect(store.defaultTargetCurrency == "EUR")
        #expect(store.hasSeenOnboarding == false)
        #expect(store.hasSeenChartOnboarding == false)
    }

    @Test("a seeded store reads the persisted values")
    func readsPersistedValues() throws {
        let seeded = try isolatedDefaults.make()
        seeded.set("CHF", forKey: UserDefaultsKeys.defaultBaseCurrency)
        seeded.set(AccentColorOption.pink.rawValue, forKey: UserDefaultsKeys.accentColor)
        seeded.set(true, forKey: UserDefaultsKeys.hasSeenOnboarding)

        let seededStore = UserDefaultsPreferencesStore(userDefaults: seeded)

        #expect(seededStore.defaultBaseCurrency == "CHF")
        #expect(seededStore.accentColor == .pink)
        #expect(seededStore.hasSeenOnboarding == true)
    }

    @Test("a changed preference writes through to the injected defaults")
    func writesThroughOnChange() {
        store.defaultTargetCurrency = "JPY"
        store.appearanceMode = .dark

        #expect(defaults.string(forKey: UserDefaultsKeys.defaultTargetCurrency) == "JPY")
        #expect(defaults.string(forKey: UserDefaultsKeys.appearanceMode) == AppearanceMode.dark.rawValue)
    }
}
