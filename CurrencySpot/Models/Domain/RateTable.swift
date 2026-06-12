//
//  RateTable.swift
//  CurrencySpot
//

import Foundation

/// USD-normalized cross-rate table: the single owner of base → target conversion math.
/// Every stored rate means "1 USD = rate units of the currency"; USD itself is
/// implicitly 1.0 when absent (historical rows never store it).
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

    /// USD → code rate, or nil when the table has no entry for the code.
    func usdRate(for code: CurrencyCode) -> Double? {
        usdRates[code] ?? (code == .usd ? 1.0 : nil)
    }

    /// base → target cross rate: (USD → target) / (USD → base).
    /// Unknown codes fall back to 1.0; a near-zero base divides by 1 instead,
    /// preserving the previous per-site divide-by-zero fallbacks.
    func crossRate(from base: CurrencyCode, to target: CurrencyCode) -> Double {
        guard base != target else { return 1.0 }
        let targetRate = usdRate(for: target) ?? 1.0
        let baseRate = usdRate(for: base) ?? 1.0
        guard abs(baseRate) > .ulpOfOne else { return targetRate }
        return targetRate / baseRate
    }

    /// Decimal conversion for scanned amounts: division happens last, in Decimal,
    /// to keep exact results exact. A near-zero base returns the amount unchanged.
    func convert(_ amount: Decimal, from base: CurrencyCode, to target: CurrencyCode) -> Decimal {
        guard base != target else { return amount }
        let targetRate = usdRate(for: target) ?? 1.0
        let baseRate = usdRate(for: base) ?? 1.0
        guard abs(baseRate) > .ulpOfOne else { return amount }
        return amount * Decimal(targetRate) / Decimal(baseRate)
    }
}
