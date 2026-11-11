import Foundation

enum OCRSplitNumberMerger {
    static func merged(
        _ tokens: [NumberToken],
        in text: NormalizedTranscript,
        isMarked: (Range<Int>) -> Bool
    ) -> [NumberToken] {
        var result: [NumberToken] = []
        var index = 0
        while index < tokens.count {
            if index + 1 < tokens.count,
               let merged = rejoined(tokens[index], tokens[index + 1], in: text),
               isMarked(merged.span) {
                result.append(merged)
                index += 2
            } else {
                result.append(tokens[index])
                index += 1
            }
        }
        return result
    }

    private static func rejoined(_ head: NumberToken, _ tail: NumberToken, in text: NormalizedTranscript) -> NumberToken? {
        guard isPlain(head), isPlain(tail) else { return nil }
        return thousandsSplitAfterComma(head, tail, in: text) ?? centsSplitBeforeZero(head, tail, in: text)
    }

    private static func isPlain(_ token: NumberToken) -> Bool {
        token.multipliedAmount == nil && !token.hasDashNotation && !token.hasFuelFraction
    }

    private static func thousandsSplitAfterComma(
        _ head: NumberToken,
        _ tail: NumberToken,
        in text: NormalizedTranscript
    ) -> NumberToken? {
        let comma = head.span.upperBound
        guard head.groups.count == 1, (1...3).contains(head.groups[0].count),
              tail.groups.count == 1, tail.groups[0].count == 3,
              text.character(at: comma) == ",", text.isSpace(comma + 1), tail.span.lowerBound == comma + 2,
              !isMeasurement(endingAt: tail.span.upperBound, in: text)
        else { return nil }
        return NumberToken(
            span: head.span.lowerBound..<tail.span.upperBound,
            groups: head.groups + tail.groups,
            separators: [","]
        )
    }

    private static func isMeasurement(endingAt end: Int, in text: NormalizedTranscript) -> Bool {
        let offset = text.isSpace(end) ? end + 1 : end
        if text.character(at: offset).map(MeasurementVocabulary.marksAfter.contains) == true
            || MeasurementVocabulary.counters.contains(where: { text.hasPrefix($0, at: offset) }) {
            return true
        }
        let word = text.word(startingAt: offset, where: \.isLetter).lowercased()
        return MeasurementVocabulary.unitWords.contains(word) || MeasurementVocabulary.countNouns.contains(word)
    }

    private static func centsSplitBeforeZero(
        _ head: NumberToken,
        _ tail: NumberToken,
        in text: NormalizedTranscript
    ) -> NumberToken? {
        guard head.groups.count == 2, head.groups[1].count == 1, tail.groups == ["0"],
              text.isSpace(head.span.upperBound), tail.span.lowerBound == head.span.upperBound + 1
        else { return nil }
        var merged = head
        merged.groups[1] += "0"
        merged.span = head.span.lowerBound..<tail.span.upperBound
        return merged
    }
}
