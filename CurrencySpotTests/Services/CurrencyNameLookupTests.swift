@testable import CurrencySpot
import Foundation
import Testing

@Suite("Currency Name Lookup Tests")
struct CurrencyNameLookupTests {
    @Test("a known ISO code resolves to a display name distinct from the code", arguments: [CurrencyCode.eur, .jpy, .gbp])
    func knownCodeResolvesToDisplayName(code: CurrencyCode) {
        let name = CurrencyNameLookup.name(for: code)

        #expect(name.isEmpty == false)
        #expect(name != code.rawValue)
    }

    @Test("an unresolvable code round-trips as the raw code")
    func unresolvableCodeRoundTrips() {
        #expect(CurrencyNameLookup.name(for: "ZZZ") == "ZZZ")
    }

    @Test("the memoized value is returned unchanged on repeat lookups")
    func repeatLookupsAreStable() {
        let first = CurrencyNameLookup.name(for: "CHF")

        #expect(CurrencyNameLookup.name(for: "CHF") == first)
        #expect(CurrencyNameLookup.name(for: "CHF") == first)
    }

    @Test("lookups are cached per code, so one code never shadows another")
    func distinctCodesGetDistinctNames() {
        let euro = CurrencyNameLookup.name(for: "EUR")
        let yen = CurrencyNameLookup.name(for: "JPY")

        #expect(euro != yen)
        #expect(CurrencyNameLookup.name(for: "EUR") == euro)
    }
}
