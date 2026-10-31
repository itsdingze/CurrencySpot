@testable import CurrencySpot
import Foundation
import Testing

@Suite("CurrencyCatalog")
struct CurrencyCatalogTests {
    private let shared: UserDefaults

    init() throws {
        shared = try #require(UserDefaults(suiteName: "CurrencyCatalogTests-shared-\(UUID().uuidString)"))
    }

    @Test("before the app shares its rates, the catalog lists widely used currencies once each, sorted by code")
    func catalogListsCommonCurrencies() {
        let codes = CurrencyCatalog.currencies(in: shared)

        #expect(codes.contains("USD"))
        #expect(codes.contains("JPY"))
        #expect(codes == codes.sorted())
        #expect(Set(codes).count == codes.count)
    }

    @Test("once the app shares its rates, the catalog offers only currencies that have a rate")
    func catalogFollowsSharedRates() {
        shared.set(["EUR", "JPY", "USD"], forKey: UserDefaultsKeys.rateCurrencies)

        #expect(CurrencyCatalog.currencies(in: shared) == ["EUR", "JPY", "USD"])
        #expect(CurrencyCatalog.search("Franc", in: shared).isEmpty)
    }

    @Test("searching matches a code or a currency name")
    func searchMatchesCodeOrName() {
        #expect(CurrencyCatalog.search("jpy", in: shared).contains("JPY"))
        #expect(CurrencyCatalog.search("Yen", in: shared).contains("JPY"))
        #expect(!CurrencyCatalog.search("Yen", in: shared).contains("USD"))
    }

    @Test("suggestions are the saved favorites, or the app's default favorites when none are saved")
    func suggestionsFollowFavorites() throws {
        let defaults = try #require(UserDefaults(suiteName: "CurrencyCatalogTests-\(UUID().uuidString)"))

        #expect(CurrencyCatalog.suggested(in: defaults) == CurrencyDefaults.favoriteCurrencies)

        defaults.set(["CHF", "JPY"], forKey: UserDefaultsKeys.favoriteCurrencies)
        #expect(CurrencyCatalog.suggested(in: defaults) == ["CHF", "JPY"])

        defaults.set([String](), forKey: UserDefaultsKeys.favoriteCurrencies)
        #expect(CurrencyCatalog.suggested(in: defaults) == CurrencyDefaults.favoriteCurrencies)
    }
}
