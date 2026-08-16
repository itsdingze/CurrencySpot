import Foundation

final class ScanConversionUseCase {
    struct DetectionResult {
        let items: [DetectedItem]
        let foundPrices: Bool
    }

    private let classifier = PriceClassifier()
    private let markerResolver = CurrencyMarkerResolver(maxGap: 1.0, minLineOverlap: 0.4)

    private var cachedRates: [ExchangeRate] = []
    private var cachedTable = RateTable([])

    private var classificationMemo: [String: PriceClassification?] = [:]

    func detect(
        in items: [RecognizedTextItem],
        baseCurrency: CurrencyCode,
        targetCurrency: CurrencyCode,
        exchangeRates: [ExchangeRate]
    ) -> DetectionResult {
        let markerAdjacent = markerResolver.numbersAdjacentToMarker(in: items)
        var foundPrices = false

        let detected = items.compactMap { item -> DetectedItem? in
            guard let conversion = evaluate(
                transcript: item.transcript,
                baseCurrency: baseCurrency,
                targetCurrency: targetCurrency,
                exchangeRates: exchangeRates
            ) else { return nil }

            let marked = markerAdjacent.contains(item.id) ? conversion.asPrice : conversion
            foundPrices = foundPrices || marked.isPrice

            return DetectedItem(
                id: item.id,
                transcript: item.transcript,
                bounds: item.bounds,
                conversion: marked
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
