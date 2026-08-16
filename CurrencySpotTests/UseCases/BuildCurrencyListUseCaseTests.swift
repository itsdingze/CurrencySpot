@testable import CurrencySpot
import Foundation
import Testing

@Suite("BuildCurrencyListUseCase Tests")
struct BuildCurrencyListUseCaseTests {
    private let build = BuildCurrencyListUseCase()

    private let rates = [
        ExchangeRate(currencyCode: .usd, rate: 1.0),
        ExchangeRate(currencyCode: .eur, rate: 0.85),
        ExchangeRate(currencyCode: .jpy, rate: 110.0),
        ExchangeRate(currencyCode: .cad, rate: 1.25),
    ]

    private func entries(
        base: CurrencyCode = .usd,
        isSearching: Bool = false,
        searchText: String = "",
        watchlist: [CurrencyCode] = [.eur, .jpy, .cad],
        sortOption: CurrencySortOption = .manual,
        weeklyChange: @escaping (CurrencyCode) -> Double = { _ in 0 }
    ) -> [CurrencyListEntry] {
        build(
            rates: rates,
            base: base,
            isSearching: isSearching,
            searchText: searchText,
            isWatchlisted: { watchlist.contains($0) },
            watchlistOrder: watchlist,
            sortOption: sortOption,
            weeklyChange: weeklyChange
        )
    }

    @Test("the base currency is never listed against itself")
    func excludesBase() {
        #expect(entries(base: .usd).contains { $0.code == .usd } == false)
        #expect(entries(base: .eur).contains { $0.code == .eur } == false)
    }

    @Test("rates are expressed relative to the base currency")
    func ratesAreBaseRelative() throws {
        let jpyFromEur = try #require(entries(base: .eur).first { $0.code == .jpy })

        #expect(abs(jpyFromEur.rate - (110.0 / 0.85)) < 0.0001)
    }

    @Test("without a search, only watchlisted currencies survive")
    func filtersToWatchlist() {
        #expect(entries(watchlist: [.jpy]).map(\.code) == [.jpy])
    }

    @Test("searching ignores the watchlist and sorts by name")
    func searchIgnoresWatchlist() {
        let results = entries(isSearching: true, searchText: "JPY", watchlist: [])

        #expect(results.map(\.code) == [.jpy])
    }

    @Test("manual sort follows the watchlist order, not the rate order")
    func manualSortFollowsWatchlist() {
        #expect(entries(watchlist: [.cad, .jpy, .eur]).map(\.code) == [.cad, .jpy, .eur])
    }

    @Test("symbol sort orders by currency code")
    func symbolSort() {
        #expect(entries(sortOption: .symbol).map(\.code) == [.cad, .eur, .jpy])
    }

    @Test("percent-change sort orders by weekly change, descending")
    func percentChangeSort() {
        let changes: [CurrencyCode: Double] = [.eur: 1.0, .jpy: 5.0, .cad: -2.0]

        #expect(entries(sortOption: .percentChange, weeklyChange: { changes[$0] ?? 0 }).map(\.code) == [.jpy, .eur, .cad])
    }

    @Test("price-change sort weighs the change by the rate")
    func priceChangeSort() {
        let changes: [CurrencyCode: Double] = [.eur: 10.0, .jpy: 1.0, .cad: 2.0]

        #expect(entries(sortOption: .priceChange, weeklyChange: { changes[$0] ?? 0 }).map(\.code) == [.jpy, .eur, .cad])
    }

    @Test("an empty rate set produces an empty list")
    func emptyRates() {
        let result = build(
            rates: [],
            base: .usd,
            isSearching: false,
            searchText: "",
            isWatchlisted: { _ in true },
            watchlistOrder: [],
            sortOption: .manual,
            weeklyChange: { _ in 0 }
        )

        #expect(result.isEmpty)
    }
}
