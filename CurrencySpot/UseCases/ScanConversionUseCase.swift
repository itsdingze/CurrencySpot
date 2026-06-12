//
//  ScanConversionUseCase.swift
//  CurrencySpot
//

import Foundation

/// Classifies a recognized camera transcript and converts its amount
/// from the base currency into the target currency.
final class ScanConversionUseCase {
    nonisolated struct ScannedConversion: Hashable, Sendable {
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

    /// The scanner calls `evaluate` once per recognized token per frame;
    /// rebuilding the table only when the rates change keeps that path O(1).
    private var cachedRates: [ExchangeRate] = []
    private var cachedTable = RateTable([])

    /// Classification is a pure function of the transcript, and scene text
    /// repeats frame after frame — memoizing skips the regex/NSDataDetector
    /// passes. Wholesale reset bounds the cache when the scene churns.
    private var classificationMemo: [String: PriceClassification?] = [:]

    func evaluate(
        transcript: String,
        baseCurrency: String,
        targetCurrency: String,
        exchangeRates: [ExchangeRate]
    ) -> ScannedConversion? {
        guard let classification = memoizedClassification(of: transcript) else { return nil }
        return ScannedConversion(
            amount: classification.amount,
            converted: convert(classification.amount, from: baseCurrency, to: targetCurrency, in: exchangeRates),
            isPrice: classification.isPrice
        )
    }

    private func memoizedClassification(of transcript: String) -> PriceClassification? {
        if let memoized = classificationMemo[transcript] {
            return memoized
        }
        if classificationMemo.count >= 512 {
            classificationMemo.removeAll(keepingCapacity: true)
        }
        let classification = classifier.classify(transcript)
        classificationMemo[transcript] = classification
        return classification
    }

    /// Delegates to RateTable's Decimal cross-rate math. Currency selections arrive
    /// as Strings from the UI edge; an unrepresentable code behaves like an unknown
    /// one (rate 1.0), matching the previous lookup-miss fallback.
    private func convert(
        _ amount: Decimal,
        from base: String,
        to target: String,
        in rates: [ExchangeRate]
    ) -> Decimal {
        guard base != target, let baseCode = CurrencyCode(base), let targetCode = CurrencyCode(target) else {
            return amount
        }
        if rates != cachedRates {
            cachedRates = rates
            cachedTable = RateTable(rates)
        }
        return cachedTable.convert(amount, from: baseCode, to: targetCode)
    }
}
