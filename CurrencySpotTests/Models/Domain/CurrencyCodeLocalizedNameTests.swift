@testable import CurrencySpot
import Foundation
import Testing

@Suite("CurrencyCode localized name")
struct CurrencyCodeLocalizedNameTests {
    @Test("a known ISO code resolves to a display name distinct from the code", arguments: [CurrencyCode.eur, .jpy, .gbp])
    func knownCodeResolvesToDisplayName(code: CurrencyCode) {
        let name = code.localizedName

        #expect(name.isEmpty == false)
        #expect(name != code.rawValue)
    }

    @Test("a name resolves in the language it is asked for", arguments: [
        ("de", "Japanischer Yen"),
        ("ja", "日本円"),
    ])
    func nameFollowsRequestedLanguage(language: String, expected: String) {
        #expect(CurrencyCode.jpy.localizedName(in: Locale(identifier: language)) == expected)
    }

    @Test("an unresolvable code round-trips as the raw code")
    func unresolvableCodeRoundTrips() {
        let unknown: CurrencyCode = "ZZZ"
        #expect(unknown.localizedName == "ZZZ")
    }

    @Test("lookups are cached per code, so one code never shadows another")
    func distinctCodesGetDistinctNames() {
        let euro = CurrencyCode.eur.localizedName
        let yen = CurrencyCode.jpy.localizedName

        #expect(euro != yen)
        #expect(CurrencyCode.eur.localizedName == euro)
    }
}
