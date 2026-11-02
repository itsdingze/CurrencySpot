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
        let detected = items.flatMap { item in
            detectedItems(
                on: item,
                reading: reader.readings(of: item, marker: markers[item.id], baseCurrency: baseCurrency),
                convert: { self.convert($0, from: baseCurrency, to: targetCurrency, in: exchangeRates) }
            )
        }
        return DetectionResult(items: detected, foundPrices: detected.contains { $0.conversion.isPrice })
    }

    private func detectedItems(
        on item: RecognizedTextItem,
        reading readings: [LinePriceReader.Reading],
        convert: (Decimal) -> Decimal
    ) -> [DetectedItem] {
        let glyphs = LineGlyphSpans(item)
        return readings.enumerated().map { ordinal, reading in
            DetectedItem(
                id: Self.itemID(line: item.id, ordinal: ordinal),
                lineID: item.id,
                transcript: item.transcript,
                tokenQuad: item.quad.slice(glyphs.tokenSpan(of: reading.token, includingMarker: reading.tokenIncludingMarker)),
                lineQuad: item.quad,
                conversion: ScannedConversion(
                    amount: reading.amount,
                    converted: convert(reading.amount),
                    isPrice: reading.isPrice
                )
            )
        }
    }

    private static func itemID(line: UUID, ordinal: Int) -> UUID {
        guard ordinal > 0 else { return line }
        var bytes = line.uuid
        bytes.14 ^= 0xA5
        bytes.15 &+= UInt8(truncatingIfNeeded: ordinal)
        return UUID(uuid: bytes)
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
