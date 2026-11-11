import Foundation

nonisolated struct RateTable: Equatable, Sendable {
    private let usdRates: [CurrencyCode: Double]

    static let empty = RateTable(rates: [:])

    init(rates: [CurrencyCode: Double]) {
        usdRates = rates
    }

    init(_ rates: [ExchangeRate]) {
        usdRates = Dictionary(rates.map { ($0.currencyCode, $0.rate) }, uniquingKeysWith: { _, last in last })
    }

    init(points: [HistoricalRatePoint]) {
        usdRates = Dictionary(points.map { ($0.currencyCode, $0.rate) }, uniquingKeysWith: { _, last in last })
    }

    var isEmpty: Bool { usdRates.isEmpty }

    func usdRate(for code: CurrencyCode) -> Double? {
        usdRates[code] ?? (code == .usd ? 1.0 : nil)
    }

    func canConvert(from base: CurrencyCode, to target: CurrencyCode) -> Bool {
        crossRate(from: base, to: target) != nil
    }

    func crossRate(from base: CurrencyCode, to target: CurrencyCode) -> Double? {
        guard base != target else { return 1.0 }
        guard let (baseRate, targetRate) = usdRates(from: base, to: target) else { return nil }
        return targetRate / baseRate
    }

    func convert(_ amount: Decimal, from base: CurrencyCode, to target: CurrencyCode) -> Decimal? {
        guard base != target else { return amount }
        guard let (baseRate, targetRate) = usdRates(from: base, to: target) else { return nil }
        return amount * Decimal(targetRate) / Decimal(baseRate)
    }

    private func usdRates(from base: CurrencyCode, to target: CurrencyCode) -> (base: Double, target: Double)? {
        guard let baseRate = usdRate(for: base), let targetRate = usdRate(for: target),
              abs(baseRate) > .ulpOfOne
        else { return nil }
        return (baseRate, targetRate)
    }
}
