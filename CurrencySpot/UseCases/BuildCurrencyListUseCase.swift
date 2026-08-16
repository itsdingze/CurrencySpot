import Foundation

struct BuildCurrencyListUseCase {
    func callAsFunction(
        rates: [ExchangeRate],
        base: CurrencyCode,
        isSearching: Bool,
        searchText: String,
        isWatchlisted: (CurrencyCode) -> Bool,
        watchlistOrder: [CurrencyCode],
        sortOption: CurrencySortOption,
        weeklyChange: (CurrencyCode) -> Double
    ) -> [CurrencyListEntry] {
        let table = RateTable(rates)

        let catalog = rates
            .filter { $0.currencyCode != base }
            .map { rate in
                CurrencyListEntry(
                    code: rate.currencyCode,
                    name: CurrencyNameLookup.name(for: rate.currencyCode),
                    rate: table.crossRate(from: base, to: rate.currencyCode)
                )
            }

        if isSearching {
            return catalog
                .filter { CurrencySearch.matches(code: $0.code, name: $0.name, searchText: searchText) }
                .sorted { $0.name < $1.name }
        }

        let watchlisted = catalog.filter { isWatchlisted($0.code) }
        return sorted(watchlisted, by: sortOption, watchlistOrder: watchlistOrder, weeklyChange: weeklyChange)
    }

    private func sorted(
        _ entries: [CurrencyListEntry],
        by sortOption: CurrencySortOption,
        watchlistOrder: [CurrencyCode],
        weeklyChange: (CurrencyCode) -> Double
    ) -> [CurrencyListEntry] {
        switch sortOption {
        case .manual:
            let position = Dictionary(
                uniqueKeysWithValues: watchlistOrder.enumerated().map { ($1, $0) }
            )
            return entries.sorted { (position[$0.code] ?? .max) < (position[$1.code] ?? .max) }
        case .symbol:
            return entries.sorted { $0.code < $1.code }
        case .name:
            return entries.sorted { $0.name < $1.name }
        case .percentChange:
            return entries.sorted { weeklyChange($0.code) > weeklyChange($1.code) }
        case .priceChange:
            return entries.sorted { lhs, rhs in
                RateMath.priceChange(rate: lhs.rate, percentChange: weeklyChange(lhs.code))
                    > RateMath.priceChange(rate: rhs.rate, percentChange: weeklyChange(rhs.code))
            }
        }
    }
}
