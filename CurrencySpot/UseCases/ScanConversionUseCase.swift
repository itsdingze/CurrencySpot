import Foundation

final class ScanConversionUseCase {
    struct DetectionResult {
        let items: [DetectedItem]
        let foundPrices: Bool
    }

    private struct AnchoredReading {
        let reading: LinePriceReader.Reading
        let perUnitSuffix: PerUnitSuffix?
        let coveredCharacters: Range<Int>
        let span: ClosedRange<CGFloat>
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
        let lines = items.map(\.quad)
        let detected = items.flatMap { item in
            let readings = reader.readings(of: item, marker: markers[item.id], baseCurrency: baseCurrency)
            return detectedItems(
                on: item,
                reading: readings,
                rowNeighbourCenter: readings.isEmpty ? nil : RowSlope.neighbourCenter(leftOf: item.quad, among: lines),
                convert: { self.convert($0, from: baseCurrency, to: targetCurrency, in: exchangeRates) }
            )
        }
        return DetectionResult(items: detected, foundPrices: detected.contains { $0.conversion.isPrice })
    }

    private func detectedItems(
        on item: RecognizedTextItem,
        reading readings: [LinePriceReader.Reading],
        rowNeighbourCenter: CGPoint?,
        convert: (Decimal) -> Decimal
    ) -> [DetectedItem] {
        let anchoredReadings = anchored(readings, on: item)
        let lineText = textQuads(of: item, outside: anchoredReadings)
        return anchoredReadings.enumerated().map { ordinal, anchored in
            DetectedItem(
                id: Self.itemID(line: item.id, ordinal: ordinal),
                lineID: item.id,
                transcript: anchoredReadings.count > 1
                    ? Self.partOfLine(naming: anchored, among: anchoredReadings, in: item.transcript)
                    : item.transcript,
                tokenQuad: item.quad.slice(anchored.span),
                lineQuad: item.quad,
                lineTextQuads: lineText,
                rowNeighbourCenter: rowNeighbourCenter,
                perUnitSuffix: anchored.perUnitSuffix?.text,
                conversion: ScannedConversion(
                    amount: anchored.reading.amount,
                    converted: convert(anchored.reading.amount),
                    isPrice: anchored.reading.isPrice
                )
            )
        }
    }

    private func anchored(_ readings: [LinePriceReader.Reading], on item: RecognizedTextItem) -> [AnchoredReading] {
        let glyphs = LineGlyphSpans(item)
        return readings.map { reading in
            let suffix = reading.isPrice
                ? PerUnitSuffix.following(reading.tokenIncludingMarker.upperBound, in: item.transcript)
                : nil
            let covered = reading.tokenIncludingMarker.lowerBound..<(suffix?.end ?? reading.tokenIncludingMarker.upperBound)
            return AnchoredReading(
                reading: reading,
                perUnitSuffix: suffix,
                coveredCharacters: covered,
                span: glyphs.tokenSpan(of: reading.token, includingMarker: covered)
            )
        }
    }

    private static func partOfLine(naming reading: AnchoredReading, among readings: [AnchoredReading], in transcript: String) -> String {
        let characters = Array(transcript)
        let start = readings
            .map(\.coveredCharacters.upperBound)
            .filter { $0 <= reading.coveredCharacters.lowerBound }
            .max() ?? 0
        let end = min(reading.coveredCharacters.upperBound, characters.count)
        guard start < end else { return transcript }
        return String(characters[start..<end].drop { $0.isWhitespace || $0.isPunctuation || $0 == "|" })
    }

    private func textQuads(of item: RecognizedTextItem, outside readings: [AnchoredReading]) -> [Quad] {
        LineGlyphSpans(item)
            .textSpans(outside: readings.map(\.coveredCharacters), clearOf: readings.map(\.span))
            .map(item.quad.slice)
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
