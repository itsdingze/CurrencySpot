@testable import CurrencySpot
import Foundation
import Testing

@Suite("CurrencySearch Tests")
struct CurrencySearchTests {
    private let rates = [
        ExchangeRate(currencyCode: .eur, rate: 0.85),
        ExchangeRate(currencyCode: .jpy, rate: 110.0),
        ExchangeRate(currencyCode: .cad, rate: 1.25),
    ]

    @Test("matches on the currency code, case insensitively")
    func matchesCode() {
        #expect(CurrencySearch.matches(code: .eur, name: "Euro", searchText: "eur"))
        #expect(CurrencySearch.matches(code: .eur, name: "Euro", searchText: "EU"))
    }

    @Test("matches on the localized name")
    func matchesName() {
        #expect(CurrencySearch.matches(code: .jpy, name: "Japanese Yen", searchText: "yen"))
        #expect(CurrencySearch.matches(code: .jpy, name: "Japanese Yen", searchText: "zzz") == false)
    }

    @Test("an empty search returns everything sorted by code")
    func emptySearchSortsByCode() {
        let results = CurrencySearch.results(in: rates, excluding: [], matching: "")

        #expect(results.map(\.currencyCode) == [.cad, .eur, .jpy])
    }

    @Test("excluded currencies never appear")
    func excludesCurrencies() {
        let results = CurrencySearch.results(in: rates, excluding: [.jpy], matching: "")

        #expect(results.map(\.currencyCode) == [.cad, .eur])
    }

    @Test("a search filters to matches only")
    func filtersToMatches() {
        let results = CurrencySearch.results(in: rates, excluding: [], matching: "CAD")

        #expect(results.map(\.currencyCode) == [.cad])
    }

    @Test("exclusion applies before the search filter")
    func exclusionBeatsSearch() {
        let results = CurrencySearch.results(in: rates, excluding: [.cad], matching: "CAD")

        #expect(results.isEmpty)
    }
}
