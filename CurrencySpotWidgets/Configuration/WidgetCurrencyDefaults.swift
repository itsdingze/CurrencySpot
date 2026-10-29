import Foundation

nonisolated enum WidgetCurrencyDefaults {
    static let base: CurrencyCode = Locale.current.currency.flatMap { CurrencyCode($0.identifier) } ?? .usd

    static let target: CurrencyCode = base == .eur ? .usd : .eur

    static let listCurrencies: [CurrencyCode] = [.usd, .eur, .gbp, .jpy, .cny, .cad, .aud, .chf]
        .filter { $0 != base }
        .prefix(7)
        .map(\.self)
}
