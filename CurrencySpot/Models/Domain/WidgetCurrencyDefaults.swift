import Foundation

nonisolated struct WidgetCurrencyDefaults {
    private static let listLimit = 7
    private static let popularCurrencies: [CurrencyCode] = [.usd, .eur, .gbp, .jpy, .cny, .cad, .aud, .chf]

    let base: CurrencyCode
    let target: CurrencyCode
    let listCurrencies: [CurrencyCode]

    init(shared: UserDefaults, locale: Locale) {
        let base = Self.currency(UserDefaultsKeys.defaultBaseCurrency, in: shared)
            ?? locale.currency.flatMap { CurrencyCode($0.identifier) }
            ?? .usd
        let target = Self.currency(UserDefaultsKeys.defaultTargetCurrency, in: shared)
        let favorites = (shared.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies)?.compactMap { CurrencyCode($0) } ?? [])
            .filter { $0 != base }

        self.base = base
        self.target = target.flatMap { $0 == base ? nil : $0 } ?? (base == .eur ? .usd : .eur)
        let topUp = Self.popularCurrencies.filter { $0 != base && !favorites.contains($0) }
        listCurrencies = Array((favorites + topUp).prefix(Self.listLimit))
    }

    static var current: WidgetCurrencyDefaults {
        WidgetCurrencyDefaults(shared: .appGroup, locale: .current)
    }

    private static func currency(_ key: String, in shared: UserDefaults) -> CurrencyCode? {
        shared.string(forKey: key).flatMap { CurrencyCode($0) }
    }
}
