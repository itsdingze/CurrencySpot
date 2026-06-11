//
//  ScanConversionUseCase.swift
//  CurrencySpot
//

import Foundation

/// Classifies a recognized camera transcript and converts its amount
/// from the base currency into the target currency.
final class ScanConversionUseCase {
    struct ScannedConversion: Equatable, Hashable, Sendable {
        let amount: Decimal
        let converted: Decimal
        let isPrice: Bool

        /// The same conversion, forced to display as a price (tap-to-convert override).
        var asPrice: ScannedConversion {
            ScannedConversion(amount: amount, converted: converted, isPrice: true)
        }

        /// The same conversion with its badge dismissed (outline only).
        var asNonPrice: ScannedConversion {
            ScannedConversion(amount: amount, converted: converted, isPrice: false)
        }
    }

    private let classifier = PriceClassifier()

    func evaluate(
        transcript: String,
        baseCurrency: String,
        targetCurrency: String,
        exchangeRates: [ExchangeRateDataValue]
    ) -> ScannedConversion? {
        guard let classification = classifier.classify(transcript) else { return nil }
        return ScannedConversion(
            amount: classification.amount,
            converted: convert(classification.amount, from: baseCurrency, to: targetCurrency, in: exchangeRates),
            isPrice: classification.isPrice
        )
    }

    /// The effective base → target rate, for display in the badge detail.
    func rate(from base: String, to target: String, in rates: [ExchangeRateDataValue]) -> Decimal {
        convert(1, from: base, to: target, in: rates)
    }

    /// Delegates to RateTable's Decimal cross-rate math. Currency selections arrive
    /// as Strings from the UI edge; an unrepresentable code behaves like an unknown
    /// one (rate 1.0), matching the previous lookup-miss fallback.
    private func convert(
        _ amount: Decimal,
        from base: String,
        to target: String,
        in rates: [ExchangeRateDataValue]
    ) -> Decimal {
        guard base != target, let baseCode = CurrencyCode(base), let targetCode = CurrencyCode(target) else {
            return amount
        }
        return RateTable(rates).convert(amount, from: baseCode, to: targetCode)
    }
}
