@testable import CurrencySpot
import Foundation
import Testing

@Suite("CurrencyCatalog")
struct CurrencyCatalogTests {
    @Test("the catalog lists widely used currencies once each, sorted by code")
    func catalogListsCommonCurrencies() {
        let codes = CurrencyCatalog.allCurrencies

        #expect(codes.contains("USD"))
        #expect(codes.contains("JPY"))
        #expect(codes == codes.sorted())
        #expect(Set(codes).count == codes.count)
    }

    @Test("searching matches a code or a currency name")
    func searchMatchesCodeOrName() {
        #expect(CurrencyCatalog.search("jpy").contains("JPY"))
        #expect(CurrencyCatalog.search("Yen").contains("JPY"))
        #expect(!CurrencyCatalog.search("Yen").contains("USD"))
    }

    @Test("suggestions are the saved favorites, or the app's default favorites when none are saved")
    func suggestionsFollowFavorites() throws {
        let defaults = try #require(UserDefaults(suiteName: "CurrencyCatalogTests-\(UUID().uuidString)"))

        #expect(CurrencyCatalog.suggested(in: defaults) == CurrencyDefaults.favoriteCurrencies)

        defaults.set(["CHF", "JPY"], forKey: UserDefaultsKeys.favoriteCurrencies)
        #expect(CurrencyCatalog.suggested(in: defaults) == ["CHF", "JPY"])
    }
}
