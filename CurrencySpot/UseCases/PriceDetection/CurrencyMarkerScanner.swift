import Foundation

enum CurrencyMarkerScanner {
    static func markers(in text: NormalizedTranscript, baseCurrency: CurrencyCode?) -> [CurrencyMarker] {
        var markers: [CurrencyMarker] = []
        var offset = 0
        while let character = text.character(at: offset) {
            if let placement = CurrencyMarkerVocabulary.symbols[character] {
                markers.append(CurrencyMarker(
                    span: offset..<offset + 1,
                    placement: placement,
                    isCents: character == CurrencyMarkerVocabulary.centSign,
                    allowsSpacedGrouping: !CurrencyMarkerVocabulary.symbolsWithoutSpacedGrouping.contains(character)
                ))
                offset += 1
                continue
            }
            if character == CurrencyMarkerVocabulary.kuai {
                if baseCurrency == CurrencyMarkerVocabulary.kuaiBaseCurrency {
                    markers.append(CurrencyMarker(
                        span: offset..<offset + 1,
                        placement: .afterNumberOnly,
                        ranksLast: true,
                        allowsSpacedGrouping: false
                    ))
                }
                offset += 1
                continue
            }
            guard character.isLetter else {
                offset += 1
                continue
            }
            let word = text.word(startingAt: offset) { $0.isLetter && !CurrencyMarkerVocabulary.isSymbolGlyph($0) }
            let span = offset..<offset + word.count
            if let marker = wordMarker(word, span: span, in: text, baseCurrency: baseCurrency) {
                markers.append(marker)
            }
            offset = span.upperBound
        }
        return markers
    }

    private static func wordMarker(
        _ word: String,
        span: Range<Int>,
        in text: NormalizedTranscript,
        baseCurrency: CurrencyCode?
    ) -> CurrencyMarker? {
        if CurrencyMarkerVocabulary.isISOCode(word) {
            return CurrencyMarker(
                span: span,
                placement: .beforeNumber,
                needsMoneyShape: CurrencyMarkerVocabulary.wordLikeISOCodes.contains(word),
                allowsPunctuationGap: true
            )
        }
        guard let local = CurrencyMarkerVocabulary.localWord(word, baseCurrency: baseCurrency) else { return nil }
        let spanWithPeriod = text.character(at: span.upperBound) == "." ? span.lowerBound..<span.upperBound + 1 : span
        return CurrencyMarker(span: spanWithPeriod, placement: local.placement, needsMoneyShape: local.needsMoneyShape)
    }
}
