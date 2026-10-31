@testable import CurrencySpot
import Foundation
import Testing

@Suite("SharedSettingsMirror")
struct SharedSettingsMirrorTests {
    private let shared: UserDefaults
    private let favorites: CurrencyCodeListStore
    private let preferences: UserDefaultsPreferencesStore
    private let ratesStore = ExchangeRatesStore()
    private let favoritesChanges = Counter()

    init() throws {
        let appDefaults = try #require(UserDefaults(suiteName: "SharedSettingsMirrorTests-app-\(UUID().uuidString)"))
        shared = try #require(UserDefaults(suiteName: "SharedSettingsMirrorTests-shared-\(UUID().uuidString)"))
        favorites = CurrencyCodeListStore(defaults: appDefaults, key: UserDefaultsKeys.favoriteCurrencies, seed: ["CHF", "JPY"])
        preferences = UserDefaultsPreferencesStore(userDefaults: appDefaults)
        preferences.defaultBaseCurrency = "EUR"
        preferences.defaultTargetCurrency = "GBP"
    }

    private func makeMirror() -> SharedSettingsMirror {
        SharedSettingsMirror(
            favorites: favorites,
            preferences: preferences,
            ratesStore: ratesStore,
            shared: shared,
            favoritesChanged: { [favoritesChanges] in favoritesChanges.value += 1 }
        )
    }

    @Test("starting shares the favorites, the default pair and the currencies that have rates")
    func startSharesSettings() {
        ratesStore.update(
            rates: [ExchangeRate(currencyCode: "USD", rate: 1), ExchangeRate(currencyCode: "GBP", rate: 0.7), ExchangeRate(currencyCode: "EUR", rate: 0.9)],
            lastUpdated: nil,
            isShowingSampleRates: false
        )

        makeMirror().start()

        #expect(shared.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies) == ["CHF", "JPY"])
        #expect(shared.string(forKey: UserDefaultsKeys.defaultBaseCurrency) == "EUR")
        #expect(shared.string(forKey: UserDefaultsKeys.defaultTargetCurrency) == "GBP")
        #expect(shared.stringArray(forKey: UserDefaultsKeys.rateCurrencies) == ["EUR", "GBP", "USD"])
    }

    @Test("sample rates are not shared as the currencies that have rates")
    func sampleRatesAreNotShared() {
        ratesStore.update(rates: [ExchangeRate(currencyCode: "USD", rate: 1)], lastUpdated: nil, isShowingSampleRates: true)

        makeMirror().start()

        #expect(shared.stringArray(forKey: UserDefaultsKeys.rateCurrencies) == nil)
    }

    @Test("later changes to favorites, the default base and rates reach the shared settings", .timeLimit(.minutes(1)))
    func laterChangesAreShared() async {
        let mirror = makeMirror()
        mirror.start()

        favorites.add("SEK")
        preferences.defaultBaseCurrency = "JPY"
        ratesStore.update(rates: [ExchangeRate(currencyCode: "USD", rate: 1), ExchangeRate(currencyCode: "NOK", rate: 10)], lastUpdated: nil, isShowingSampleRates: false)

        await waitUntil { shared.stringArray(forKey: UserDefaultsKeys.rateCurrencies) == ["NOK", "USD"] }
        #expect(shared.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies) == ["CHF", "JPY", "SEK"])
        #expect(shared.string(forKey: UserDefaultsKeys.defaultBaseCurrency) == "JPY")
    }

    @Test("Siri's currency phrases refresh at start and when favorites change, not on other settings", .timeLimit(.minutes(1)))
    func favoritesChangeRefreshesPhrases() async {
        let mirror = makeMirror()
        mirror.start()
        #expect(favoritesChanges.value == 1)

        preferences.defaultBaseCurrency = "JPY"
        await waitUntil { shared.string(forKey: UserDefaultsKeys.defaultBaseCurrency) == "JPY" }
        #expect(favoritesChanges.value == 1)

        favorites.add("SEK")
        await waitUntil { favoritesChanges.value == 2 }
    }
}

private final class Counter {
    var value = 0
}
