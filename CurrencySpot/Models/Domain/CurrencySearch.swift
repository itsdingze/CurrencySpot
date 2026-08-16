import Foundation

enum CurrencySearch {
    static func matches(code: CurrencyCode, name: String, searchText: String) -> Bool {
        code.rawValue.localizedStandardContains(searchText) || name.localizedStandardContains(searchText)
    }

    static func results(
        in rates: [ExchangeRate],
        excluding excluded: Set<CurrencyCode>,
        matching searchText: String
    ) -> [ExchangeRate] {
        let available = rates.filter { !excluded.contains($0.currencyCode) }

        guard !searchText.isEmpty else {
            return available.sorted { $0.currencyCode < $1.currencyCode }
        }

        return available.filter { rate in
            matches(
                code: rate.currencyCode,
                name: CurrencyNameLookup.name(for: rate.currencyCode),
                searchText: searchText
            )
        }
    }
}
