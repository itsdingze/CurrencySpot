import Foundation

final class ScanConversionUseCase {
    struct DetectionResult {
        let items: [DetectedItem]
        let foundPrices: Bool
    }

    private struct ClassificationKey: Hashable {
        let transcript: String
        let baseCurrency: CurrencyCode
    }

    private let markerResolver = CurrencyMarkerResolver(maxGap: 1.0, minLineOverlap: 0.4)

    private var cachedRates: [ExchangeRate] = []
    private var cachedTable = RateTable([])

    private var classificationMemo: [ClassificationKey: PriceClassification?] = [:]

    func detect(
        in items: [RecognizedTextItem],
        baseCurrency: CurrencyCode,
        targetCurrency: CurrencyCode,
        exchangeRates: [ExchangeRate]
    ) -> DetectionResult {
        let markers = markerResolver.markersBesideNumbers(in: items)
        var foundPrices = false

        let detected = items.compactMap { item -> DetectedItem? in
            let transcript = markers[item.id].map { $0.attached(to: item.transcript) } ?? item.transcript
            guard let conversion = evaluate(
                transcript: transcript,
                baseCurrency: baseCurrency,
                targetCurrency: targetCurrency,
                exchangeRates: exchangeRates
            ) else { return nil }

            foundPrices = foundPrices || conversion.isPrice

            return DetectedItem(
                id: item.id,
                transcript: item.transcript,
                bounds: item.bounds,
                conversion: conversion
            )
        }

        return DetectionResult(items: detected, foundPrices: foundPrices)
    }

    private func evaluate(
        transcript: String,
        baseCurrency: CurrencyCode,
        targetCurrency: CurrencyCode,
        exchangeRates: [ExchangeRate]
    ) -> ScannedConversion? {
        let key = ClassificationKey(transcript: transcript, baseCurrency: baseCurrency)
        guard let classification = memoizedClassification(of: key) else { return nil }
        return ScannedConversion(
            amount: classification.amount,
            converted: convert(classification.amount, from: baseCurrency, to: targetCurrency, in: exchangeRates),
            isPrice: classification.isPrice
        )
    }

    private func memoizedClassification(of key: ClassificationKey) -> PriceClassification? {
        if let memoized = classificationMemo[key] {
            return memoized
        }
        if classificationMemo.count >= 512 {
            classificationMemo.removeAll(keepingCapacity: true)
        }
        let classification = PriceClassifier(baseCurrency: key.baseCurrency).classify(key.transcript)
        classificationMemo[key] = classification
        return classification
    }

    private func convert(
        _ amount: Decimal,
        from base: CurrencyCode,
        to target: CurrencyCode,
        in rates: [ExchangeRate]
    ) -> Decimal {
        guard base != target else { return amount }
        if rates != cachedRates {
            cachedRates = rates
            cachedTable = RateTable(rates)
        }
        return cachedTable.convert(amount, from: base, to: target)
    }
}
