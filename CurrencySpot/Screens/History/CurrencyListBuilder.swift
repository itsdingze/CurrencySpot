//
//  CurrencyListBuilder.swift
//  CurrencySpot
//

import Foundation

/// Pure builder for the History screen's currency rows: turns the shared rate
/// snapshot into either the searchable catalog or the ordered watchlist,
/// filtered and sorted per the current options. Trend resolution stays with the
/// caller through the `weeklyChange` closure, keeping this free of view-model state.
enum CurrencyListBuilder {
    /// Builds the rows to display. Searching spans the full catalog (each row
    /// carries an add/remove toggle), ordered by name; browsing shows only
    /// watchlisted codes in the chosen order.
    static func build(
        rates: [ExchangeRate],
        base: String,
        isSearching: Bool,
        searchText: String,
        isWatchlisted: (String) -> Bool,
        watchlistOrder: [String],
        sortOption: CurrencySortOption,
        weeklyChange: (String) -> Double
    ) -> [CurrencyListEntry] {
        let baseRate = rates.first { $0.currencyCode.rawValue == base }?.rate ?? 1.0

        // Every available currency except the base, with its base-adjusted rate.
        let catalog = rates
            .filter { $0.currencyCode.rawValue != base }
            .map { rate in
                CurrencyListEntry(
                    code: rate.currencyCode.rawValue,
                    name: CurrencyNameLookup.name(for: rate.currencyCode.rawValue),
                    rate: rate.rate / baseRate
                )
            }

        if isSearching {
            return catalog
                .filter { entry in
                    entry.code.localizedStandardContains(searchText) ||
                        entry.name.localizedStandardContains(searchText)
                }
                .sorted { $0.name < $1.name }
        }

        let watchlisted = catalog.filter { isWatchlisted($0.code) }
        return sorted(watchlisted, by: sortOption, watchlistOrder: watchlistOrder, weeklyChange: weeklyChange)
    }

    /// Orders watchlisted entries per `sortOption`. Manual restores the stored
    /// drag order; change-based sorts surface the biggest movers first.
    private static func sorted(
        _ entries: [CurrencyListEntry],
        by sortOption: CurrencySortOption,
        watchlistOrder: [String],
        weeklyChange: (String) -> Double
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
            // Absolute weekly change in the base-adjusted rate, derived from the percentage.
            return entries.sorted { lhs, rhs in
                let lhsChange = lhs.rate * weeklyChange(lhs.code) / 100
                let rhsChange = rhs.rate * weeklyChange(rhs.code) / 100
                return lhsChange > rhsChange
            }
        }
    }
}
