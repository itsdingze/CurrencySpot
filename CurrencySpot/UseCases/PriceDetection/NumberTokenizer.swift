import Foundation

struct NumberToken {
    var span: Range<Int>
    var groups: [String]
    var separators: [Character]
    var hasDashNotation = false
    var multipliedAmount: Decimal?
    var isThousandsShorthand = false
    var hasFuelFraction = false

    var isYearShaped: Bool {
        guard separators.isEmpty, !hasDashNotation, multipliedAmount == nil, let digits = groups.first,
              digits.count == 4, let year = Int(digits)
        else { return false }
        return (1900...2099).contains(year)
    }
}

enum NumberTokenizer {
    private static let groupSeparators: Set<Character> = [".", ",", "'"]
    private static let dashNotationLeads: Set<Character> = [".", ",", "/", ":"]
    private static let multipliers: [Character: Decimal] = [
        "万": 10_000, "萬": 10_000, "만": 10_000,
        "千": 1_000, "천": 1_000,
        "億": 100_000_000, "亿": 100_000_000, "억": 100_000_000,
    ]

    private static let thousandsShorthandWords: Set<String> = ["K", "k", "rb"]
    private static let nineTenthsSuffix = " 9/10"

    static func tokens(
        in text: NormalizedTranscript,
        fractionDigits: Int,
        readsThousandsShorthand: Bool,
        readsPerLitreFraction: Bool
    ) -> [NumberToken] {
        var tokens: [NumberToken] = []
        var offset = 0
        while offset < text.count {
            guard text.isDigit(offset) else {
                offset += 1
                continue
            }
            let plain = plainToken(at: offset, in: text)
            let shorthand = readsThousandsShorthand
                ? thousandsShorthand(following: plain, in: text, fractionDigits: fractionDigits)
                : nil
            let token = shorthand ?? decorated(
                plain,
                in: text,
                fractionDigits: fractionDigits,
                readsPerLitreFraction: readsPerLitreFraction
            )
            tokens.append(token)
            offset = token.span.upperBound
        }
        return tokens
    }

    private static func plainToken(at start: Int, in text: NormalizedTranscript) -> NumberToken {
        var end = digitRunEnd(from: start, in: text)
        var groups = [text.string(start..<end)]
        var separators: [Character] = []
        while let separator = text.character(at: end), groupSeparators.contains(separator), text.isDigit(end + 1) {
            let groupEnd = digitRunEnd(from: end + 1, in: text)
            if separator == "'", groupEnd - (end + 1) != 3 { break }
            separators.append(separator)
            groups.append(text.string(end + 1..<groupEnd))
            end = groupEnd
        }
        if hasEuroCents(at: end, in: text) {
            separators.append(separators.contains(".") ? "," : ".")
            groups.append(text.string(end + 1..<end + 3))
            end += 3
        }
        return NumberToken(span: start..<end, groups: groups, separators: separators)
    }

    private static func hasEuroCents(at offset: Int, in text: NormalizedTranscript) -> Bool {
        text.character(at: offset) == CurrencyMarkerVocabulary.euroSign
            && text.isDigit(offset + 1) && text.isDigit(offset + 2) && !text.isDigit(offset + 3)
    }

    private static func thousandsShorthand(
        following token: NumberToken,
        in text: NormalizedTranscript,
        fractionDigits: Int
    ) -> NumberToken? {
        let word = text.word(startingAt: token.span.upperBound, where: \.isLetter)
        guard thousandsShorthandWords.contains(word),
              let amount = NumberShape(token, fractionDigits: fractionDigits).amount
        else { return nil }
        return NumberToken(
            span: token.span.lowerBound..<token.span.upperBound + word.count,
            groups: [],
            separators: [],
            multipliedAmount: amount * 1_000,
            isThousandsShorthand: true
        )
    }

    private static func fuelPrice(
        _ token: NumberToken,
        in text: NormalizedTranscript,
        readsPerLitreFraction: Bool
    ) -> NumberToken? {
        guard token.groups.count == 2, token.separators != ["'"], let fraction = token.groups.last else { return nil }
        let end = token.span.upperBound
        var fuel = token
        fuel.hasFuelFraction = true
        if readsPerLitreFraction, token.groups[0].count == 1, fraction.count == 3, isFollowedByPerLitre(end, in: text) {
            return fuel
        }
        guard fraction.count == 2, token.separators == ["."], text.hasPrefix(nineTenthsSuffix, at: end),
              !text.isDigit(end + nineTenthsSuffix.count)
        else { return nil }
        fuel.groups[1] = fraction + "9"
        fuel.span = token.span.lowerBound..<end + nineTenthsSuffix.count
        return fuel
    }

    private static func isFollowedByPerLitre(_ end: Int, in text: NormalizedTranscript) -> Bool {
        var offset = text.isSpace(end) ? end + 1 : end
        if let symbol = text.character(at: offset), CurrencyMarkerVocabulary.symbols[symbol] != nil {
            offset += text.isSpace(offset + 1) ? 2 : 1
        }
        guard text.character(at: offset) == "/" else { return false }
        let unitStart = text.isSpace(offset + 1) ? offset + 2 : offset + 1
        let unit = text.word(startingAt: unitStart, where: \.isLetter)
        return unit == "l" || unit == "L"
    }

    private static func decorated(
        _ token: NumberToken,
        in text: NormalizedTranscript,
        fractionDigits: Int,
        readsPerLitreFraction: Bool
    ) -> NumberToken {
        if let fuel = fuelPrice(token, in: text, readsPerLitreFraction: readsPerLitreFraction) {
            return fuel
        }
        guard hasDashNotation(at: token.span.upperBound, in: text) else {
            return multiplierChain(startingWith: token, in: text, fractionDigits: fractionDigits) ?? token
        }
        var dashed = token
        dashed.hasDashNotation = true
        dashed.span = token.span.lowerBound..<token.span.upperBound + 2
        return dashed
    }

    private static func hasDashNotation(at offset: Int, in text: NormalizedTranscript) -> Bool {
        guard let lead = text.character(at: offset), dashNotationLeads.contains(lead),
              text.character(at: offset + 1) == "-"
        else { return false }
        let following = text.character(at: offset + 2)
        return !text.isDigit(offset + 2) && following != "." && following != "-"
    }

    private static func multiplierChain(
        startingWith head: NumberToken,
        in text: NormalizedTranscript,
        fractionDigits: Int
    ) -> NumberToken? {
        guard let glyph = text.character(at: head.span.upperBound), let multiplier = multipliers[glyph],
              let headAmount = NumberShape(head, fractionDigits: fractionDigits).amount
        else { return nil }

        var total = headAmount * multiplier
        var lastMultiplier = multiplier
        var end = head.span.upperBound + 1
        while true {
            let partStart = text.isSpace(end) && text.isDigit(end + 1) ? end + 1 : end
            guard text.isDigit(partStart) else { break }
            let part = plainToken(at: partStart, in: text)
            guard let partAmount = NumberShape(part, fractionDigits: fractionDigits).amount else { break }
            if let nextGlyph = text.character(at: part.span.upperBound), let nextMultiplier = multipliers[nextGlyph] {
                guard nextMultiplier < lastMultiplier else { break }
                total += partAmount * nextMultiplier
                lastMultiplier = nextMultiplier
                end = part.span.upperBound + 1
                continue
            }
            if partStart == end {
                total += partAmount
                end = part.span.upperBound
            }
            break
        }
        return NumberToken(span: head.span.lowerBound..<end, groups: [], separators: [], multipliedAmount: total)
    }

    private static func digitRunEnd(from start: Int, in text: NormalizedTranscript) -> Int {
        var end = start
        while text.isDigit(end) { end += 1 }
        return end
    }
}
