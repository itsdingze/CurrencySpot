import Foundation

final class ScanConversionUseCase {
    struct DetectionResult {
        let items: [DetectedItem]
        let foundPrices: Bool
    }

    private let markerResolver = CurrencyMarkerResolver(maxGap: 1.0, minLineOverlap: 0.4)
    private let reader = LinePriceReader()

    private var cachedRates: [ExchangeRate] = []
    private var cachedTable = RateTable([])

    func detect(
        in items: [RecognizedTextItem],
        baseCurrency: CurrencyCode,
        targetCurrency: CurrencyCode,
        exchangeRates: [ExchangeRate]
    ) -> DetectionResult {
        let markers = markerResolver.markersBesideNumbers(in: items)
        let detected = items.compactMap { item -> DetectedItem? in
            guard let reading = reader.readings(of: item, marker: markers[item.id], baseCurrency: baseCurrency).first else {
                return nil
            }
            let span = LineGlyphSpans(item).tokenSpan(of: reading.token, includingMarker: reading.tokenIncludingMarker)
            return DetectedItem(
                id: item.id,
                transcript: item.transcript,
                tokenQuad: item.quad.slice(span),
                lineQuad: item.quad,
                conversion: ScannedConversion(
                    amount: reading.amount,
                    converted: convert(reading.amount, from: baseCurrency, to: targetCurrency, in: exchangeRates),
                    isPrice: reading.isPrice
                )
            )
        }
        return DetectionResult(items: detected, foundPrices: detected.contains { $0.conversion.isPrice })
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
