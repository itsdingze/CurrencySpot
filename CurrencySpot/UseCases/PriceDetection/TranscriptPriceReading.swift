import Foundation

struct TranscriptPriceReading {
    private static let longIntegerDigitCount = 7

    private var leadingMarkedPrices: [PriceCandidate] = []
    private var lastRankedMarkedPrices: [PriceCandidate] = []
    private(set) var unmarkedPricesWithCents: [PriceCandidate] = []
    private(set) var unmarkedPrices: [PriceCandidate] = []
    private(set) var outlines: [PriceCandidate] = []

    var markedPrices: [PriceCandidate] {
        leadingMarkedPrices.isEmpty ? lastRankedMarkedPrices : leadingMarkedPrices
    }

    init(_ transcript: String, baseCurrency: CurrencyCode?) {
        let text = NormalizedTranscript(transcript)
        let fractionDigits = CurrencyFractionDigits.count(for: baseCurrency)
        let markers = CurrencyMarkerScanner.markers(in: text, baseCurrency: baseCurrency)
        let binder = CurrencyMarkerBinder(text: text, markers: markers)
        let readTokens = NumberTokenizer.tokens(
            in: text,
            fractionDigits: fractionDigits,
            readsThousandsShorthand: BaseCurrencyNumberRules.readsThousandsShorthand(under: baseCurrency),
            readsPerLitreFraction: BaseCurrencyNumberRules.readsPerLitreFraction(under: baseCurrency)
        )
        let tokens = SpacedGroupingMerger.merged(
            readTokens,
            in: text,
            isMarked: binder.hasAdjacentSpaceGroupingMarker
        )
        let shapes = tokens.map { NumberShape($0, fractionDigits: fractionDigits) }
        var noise = NumberNoiseRules(text: text, tokens: tokens)
        let bindings = binder.bind(tokens) { [noise] index, marker in
            let token = tokens[index]
            let shape = shapes[index]
            guard !noise.blocksBinding(token), shape.amount.map({ $0 != 0 }) ?? false else { return false }
            guard marker.needsMoneyShape else { return true }
            return (shape.isMoneyShaped || token.hasDashNotation) && !noise.opensARange(token)
        }

        for (index, token) in tokens.enumerated() {
            let range = text.originalRange(token.span)
            if let marker = bindings[index] ?? markers.first(where: { token.span.contains($0.span.lowerBound) }) {
                let spanIncludingMarker = min(token.span.lowerBound, marker.span.lowerBound)
                    ..< max(token.span.upperBound, marker.span.upperBound)
                recordMarked(
                    shapes[index],
                    marker: marker,
                    range: range,
                    rangeIncludingMarker: text.originalRange(spanIncludingMarker)
                )
            } else if !noise.isNoise(token, shape: shapes[index]) {
                recordUnmarked(
                    token,
                    shape: shapes[index],
                    range: range,
                    isWholePrice: (token.hasDashNotation || token.isThousandsShorthand) && !noise.isFollowedByWord(token)
                )
            }
        }
    }

    private mutating func recordMarked(
        _ shape: NumberShape,
        marker: CurrencyMarker,
        range: Range<String.Index>,
        rangeIncludingMarker: Range<String.Index>
    ) {
        guard let amount = shape.amount else { return }
        let value = marker.isCents ? amount / 100 : amount
        let price = PriceCandidate(amount: value, isPrice: true, range: range, rangeIncludingMarker: rangeIncludingMarker)
        if marker.ranksLast {
            lastRankedMarkedPrices.append(price)
        } else {
            leadingMarkedPrices.append(price)
        }
    }

    private mutating func recordUnmarked(
        _ token: NumberToken,
        shape: NumberShape,
        range: Range<String.Index>,
        isWholePrice: Bool
    ) {
        guard let amount = shape.amount else { return }
        let price = PriceCandidate(amount: amount, isPrice: true, range: range, rangeIncludingMarker: range)
        let outline = PriceCandidate(amount: amount, isPrice: false, range: range, rangeIncludingMarker: range)
        let isLong = shape.integerDigitCount >= Self.longIntegerDigitCount

        if isWholePrice {
            unmarkedPrices.append(price)
            unmarkedPricesWithCents.append(price)
            return
        }
        if token.hasDashNotation {
            outlines.append(outline)
            return
        }
        switch shape.kind {
        case .money where isLong, .grouped where isLong:
            outlines.append(outline)
        case .money:
            unmarkedPrices.append(price)
            unmarkedPricesWithCents.append(price)
        case .grouped:
            unmarkedPrices.append(price)
        case .integer where isLong, .malformed:
            return
        case .integer, .oneDecimal, .otherDecimal, .multiplied:
            outlines.append(outline)
        }
    }
}
