@testable import CurrencySpot
import Foundation
import Testing

@Suite("WidgetCurrencyDefaults")
struct WidgetCurrencyDefaultsTests {
    private let shared: UserDefaults

    init() throws {
        shared = try #require(UserDefaults(suiteName: "WidgetCurrencyDefaultsTests-\(UUID().uuidString)"))
    }

    @Test("a new widget starts on the app's default pair and favorites, without the base in its list")
    func followsAppSettings() {
        shared.set("CHF", forKey: UserDefaultsKeys.defaultBaseCurrency)
        shared.set("SEK", forKey: UserDefaultsKeys.defaultTargetCurrency)
        shared.set(["CHF", "SEK", "NOK"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let defaults = WidgetCurrencyDefaults(shared: shared, locale: Locale(identifier: "en_US"))

        #expect(defaults.base == "CHF")
        #expect(defaults.target == "SEK")
        #expect(defaults.listCurrencies == ["SEK", "NOK", "USD", "EUR", "GBP", "JPY", "CNY"])
    }

    @Test("before the app has shared its settings, a widget starts on the device region's currency")
    func fallsBackToRegion() {
        let defaults = WidgetCurrencyDefaults(shared: shared, locale: Locale(identifier: "ja_JP"))

        #expect(defaults.base == "JPY")
        #expect(defaults.target == "EUR")
        #expect(!defaults.listCurrencies.contains("JPY"))
        #expect(!defaults.listCurrencies.isEmpty)
    }

    @Test("with no favorites besides the base, a new list widget starts on popular currencies instead of none")
    func emptyFavoritesFallBack() {
        shared.set("USD", forKey: UserDefaultsKeys.defaultBaseCurrency)
        shared.set(["USD"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let defaults = WidgetCurrencyDefaults(shared: shared, locale: Locale(identifier: "en_US"))

        #expect(defaults.listCurrencies == ["EUR", "GBP", "JPY", "CNY", "CAD", "AUD", "CHF"])
    }

    @Test("a new large list widget fills all seven rows, topping up favorites with popular currencies")
    func topsUpToSevenRows() {
        shared.set("USD", forKey: UserDefaultsKeys.defaultBaseCurrency)
        shared.set(["USD", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let defaults = WidgetCurrencyDefaults(shared: shared, locale: Locale(identifier: "en_US"))

        #expect(defaults.listCurrencies == ["EUR", "GBP", "JPY", "CNY", "CAD", "AUD", "CHF"])
    }

    @Test("topping up keeps the user's favorites in their own order ahead of popular currencies")
    func topUpKeepsFavoriteOrder() {
        shared.set("USD", forKey: UserDefaultsKeys.defaultBaseCurrency)
        shared.set(["USD", "CAD", "EUR", "GBP"], forKey: UserDefaultsKeys.favoriteCurrencies)

        let defaults = WidgetCurrencyDefaults(shared: shared, locale: Locale(identifier: "en_US"))

        #expect(defaults.listCurrencies == ["CAD", "EUR", "GBP", "JPY", "CNY", "AUD", "CHF"])
    }

    @Test("a shared target equal to the base is replaced so the pair widget shows two currencies")
    func targetDiffersFromBase() {
        shared.set("EUR", forKey: UserDefaultsKeys.defaultBaseCurrency)
        shared.set("EUR", forKey: UserDefaultsKeys.defaultTargetCurrency)

        let defaults = WidgetCurrencyDefaults(shared: shared, locale: Locale(identifier: "en_US"))

        #expect(defaults.target == "USD")
    }
}
