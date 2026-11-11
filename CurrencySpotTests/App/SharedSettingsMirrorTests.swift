@testable import CurrencySpot
import Foundation
import Testing

@Suite("SharedSettingsMirror")
struct SharedSettingsMirrorTests {
    private let shared: UserDefaults
    private let favorites: CurrencyCodeListStore
    private let preferences: UserDefaultsPreferencesStore
    private let ratesStore = ExchangeRatesStore()
    private let language: UserDefaultsAppLanguageStore
    private let favoritesChanges = Counter()
    private let ratesRefreshes = Counter()
    private let languageChanges = Counter()

    init() throws {
        let appDomain = "SharedSettingsMirrorTests-app-\(UUID().uuidString)"
        let appDefaults = try #require(UserDefaults(suiteName: appDomain))
        shared = try #require(UserDefaults(suiteName: "SharedSettingsMirrorTests-shared-\(UUID().uuidString)"))
        favorites = CurrencyCodeListStore(defaults: appDefaults, key: UserDefaultsKeys.favoriteCurrencies, seed: ["CHF", "JPY"])
        preferences = UserDefaultsPreferencesStore(userDefaults: appDefaults)
        preferences.defaultBaseCurrency = "EUR"
        preferences.defaultTargetCurrency = "GBP"
        language = UserDefaultsAppLanguageStore(userDefaults: appDefaults, domainName: appDomain, availableIdentifiers: ["de", "en", "ja"])
    }

    private func makeMirror() -> SharedSettingsMirror {
        SharedSettingsMirror(
            favorites: favorites,
            preferences: preferences,
            ratesStore: ratesStore,
            language: language,
            shared: shared,
            favoritesChanged: { [favoritesChanges] in favoritesChanges.value += 1 },
            ratesRefreshed: { [ratesRefreshes] in ratesRefreshes.value += 1 },
            languageChanged: { [languageChanges] in languageChanges.value += 1 }
        )
    }

    @Test("the language chosen in the app is shared, and choosing System clears it", .timeLimit(.minutes(1)))
    func chosenLanguageIsShared() async {
        language.selectedLanguage = AppLanguage(identifier: "de")
        let mirror = makeMirror()
        mirror.start()
        #expect(shared.string(forKey: UserDefaultsKeys.appLanguage) == "de")

        language.resetToSystem()

        await waitUntil { shared.string(forKey: UserDefaultsKeys.appLanguage) == nil }
    }

    @Test("widgets reload when the shared language changes, and not on a launch that leaves it unchanged", .timeLimit(.minutes(1)))
    func languageChangeReloadsWidgets() async {
        makeMirror().start()
        #expect(languageChanges.value == 0)

        language.selectedLanguage = AppLanguage(identifier: "ja")
        let relaunched = makeMirror()
        relaunched.start()
        #expect(languageChanges.value == 1)

        language.selectedLanguage = AppLanguage(identifier: "de")
        await waitUntil { languageChanges.value == 2 }

        language.resetToSystem()
        await waitUntil { languageChanges.value == 3 }
        withExtendedLifetime(relaunched) {}
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

    @Test("widgets reload once for each newer rates fetch, including across launches", .timeLimit(.minutes(1)))
    func newerRatesReloadWidgets() async {
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        let afternoon = morning.addingTimeInterval(6 * 60 * 60)
        let rates = [ExchangeRate(currencyCode: "USD", rate: 1)]
        ratesStore.update(rates: rates, lastUpdated: morning, isShowingSampleRates: false)
        makeMirror().start()
        #expect(ratesRefreshes.value == 1)

        let relaunched = makeMirror()
        relaunched.start()
        #expect(ratesRefreshes.value == 1)

        ratesStore.update(rates: rates, lastUpdated: afternoon, isShowingSampleRates: false)
        await waitUntil { ratesRefreshes.value == 2 }
        withExtendedLifetime(relaunched) {}
    }

    @Test("sample rates never reload the widgets")
    func sampleRatesDoNotReloadWidgets() {
        ratesStore.update(rates: [ExchangeRate(currencyCode: "USD", rate: 1)], lastUpdated: .now, isShowingSampleRates: true)

        makeMirror().start()

        #expect(ratesRefreshes.value == 0)
    }
}

private final class Counter {
    var value = 0
}
