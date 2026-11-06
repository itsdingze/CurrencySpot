import Foundation

struct NumberNoiseRules {
    private static let dateOrPhoneDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
            | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
    )

    private let text: NormalizedTranscript
    private let clockSpans: [Range<Int>]
    private lazy var dateOrPhoneSpans = Self.dateOrPhoneSpans(in: text)
    private lazy var usesDotTimes = clockSpans.contains { clock in dateOrPhoneSpans.contains { $0.overlaps(clock) } }

    init(text: NormalizedTranscript, tokens: [NumberToken]) {
        self.text = text
        clockSpans = tokens.filter(Self.isClockShaped).map(\.span)
    }

    func blocksBinding(_ token: NumberToken) -> Bool {
        isTimeOrRatio(token.span)
    }

    func opensARange(_ token: NumberToken) -> Bool {
        text.character(at: token.span.upperBound) == "-" && text.isDigit(token.span.upperBound + 1)
    }

    func isFollowedByWord(_ token: NumberToken) -> Bool {
        let wordStart = text.isSpace(token.span.upperBound) ? token.span.upperBound + 1 : token.span.upperBound
        return text.character(at: wordStart)?.isLetter == true
    }

    mutating func isNoise(_ token: NumberToken, shape: NumberShape) -> Bool {
        blocksBinding(token)
            || isGluedBefore(token.span.lowerBound)
            || isGluedAfter(token.span.upperBound)
            || hasMarkBefore(token.span.lowerBound)
            || hasMarkAfter(token.span.upperBound)
            || hasSpacedUnitWord(after: token.span.upperBound, shape: shape)
            || hasCounter(after: token.span.upperBound)
            || (!token.hasFuelFraction && dateOrPhoneSpans.contains { $0.overlaps(token.span) })
            || (Self.isClockShaped(token) && usesDotTimes)
    }

    private static func isClockShaped(_ token: NumberToken) -> Bool {
        guard token.separators == ["."], token.groups.count == 2, token.groups[1].count == 2,
              let hour = Int(token.groups[0]), let minute = Int(token.groups[1])
        else { return false }
        return hour <= 23 && minute <= 59
    }

    private func isTimeOrRatio(_ span: Range<Int>) -> Bool {
        (text.character(at: span.lowerBound - 1) == ":" && text.isDigit(span.lowerBound - 2))
            || (text.character(at: span.upperBound) == ":" && text.isDigit(span.upperBound + 1))
    }

    private func isGluedBefore(_ start: Int) -> Bool {
        guard let previous = text.character(at: start - 1) else { return false }
        if MeasurementVocabulary.gluedPrefixes.contains(previous) || previous == ":" { return true }
        if previous == "-" { return text.isDigit(start - 2) }
        if previous == ".", let beforePeriod = text.character(at: start - 2), beforePeriod.isASCII, beforePeriod.isLetter {
            return !isCurrencyWord(endingBefore: start - 1)
        }
        guard previous.isASCII, previous.isLetter else { return false }
        return !isCurrencyWord(endingBefore: start)
    }

    private func isGluedAfter(_ end: Int) -> Bool {
        guard let next = text.character(at: end) else { return false }
        switch next {
        case ":":
            return true
        case "-":
            return text.isDigit(end + 1) || isUnitWord(text.word(startingAt: end + 1, where: Self.isLatinLetter))
        case "/":
            return text.isDigit(end + 1)
        default:
            guard Self.isLatinLetter(next) else { return false }
            return !CurrencyMarkerVocabulary.isCurrencyWord(text.word(startingAt: end, where: Self.isLatinLetter))
        }
    }

    private func hasMarkBefore(_ start: Int) -> Bool {
        if let previous = text.character(at: start - 1), MeasurementVocabulary.gluedMarksBefore.contains(previous) {
            return true
        }
        let offset = text.isSpace(start - 1) ? start - 2 : start - 1
        return text.character(at: offset).map(MeasurementVocabulary.marksBefore.contains) ?? false
    }

    private func hasMarkAfter(_ end: Int) -> Bool {
        if let next = text.character(at: end), MeasurementVocabulary.gluedMarksAfter.contains(next) { return true }
        let offset = text.isSpace(end) ? end + 1 : end
        return text.character(at: offset).map(MeasurementVocabulary.marksAfter.contains) ?? false
    }

    private func hasSpacedUnitWord(after end: Int, shape: NumberShape) -> Bool {
        guard text.isSpace(end) else { return false }
        let word = text.word(startingAt: end + 1, where: Self.isLatinLetter)
        guard !word.isEmpty, !Self.isSizeOrTaxLabel(word, after: shape) else { return false }
        let wordEnd = end + 1 + word.count
        switch word.lowercased() {
        case "w" where text.character(at: wordEnd) == "/":
            return false
        case "x" where shape.kind != .integer:
            return !isPlainQuantity(after: wordEnd)
        default:
            return isUnitWord(word) || MeasurementVocabulary.countNouns.contains(word.lowercased())
        }
    }

    private func isPlainQuantity(after wordEnd: Int) -> Bool {
        guard text.isSpace(wordEnd), text.isDigit(wordEnd + 1) else { return false }
        var end = wordEnd + 1
        while text.isDigit(end) { end += 1 }
        let isFractional = text.character(at: end).map { $0 == "." || $0 == "," } == true && text.isDigit(end + 1)
        return end - (wordEnd + 1) <= 3 && !isFractional
    }

    private func hasCounter(after end: Int) -> Bool {
        let offset = text.isSpace(end) ? end + 1 : end
        return MeasurementVocabulary.counters.contains { text.hasPrefix($0, at: offset) }
    }

    private func isCurrencyWord(endingBefore end: Int) -> Bool {
        CurrencyMarkerVocabulary.isCurrencyWord(text.word(endingBefore: end, where: Self.isLatinLetter))
    }

    private func isUnitWord(_ word: String) -> Bool {
        MeasurementVocabulary.unitWords.contains(word.lowercased())
    }

    private static func isSizeOrTaxLabel(_ word: String, after shape: NumberShape) -> Bool {
        word.count == 1 && word.allSatisfy(\.isUppercase) && shape.kind == .money
            && shape.amount.map { $0 >= 1 } == true
    }

    private static func isLatinLetter(_ character: Character) -> Bool {
        guard character.isLetter, let scalar = character.unicodeScalars.first else { return false }
        return scalar.value < 0x0530
    }

    private static func dateOrPhoneSpans(in text: NormalizedTranscript) -> [Range<Int>] {
        guard let dateOrPhoneDetector else { return [] }
        let transcript = text.transcript
        let fullRange = NSRange(transcript.startIndex..., in: transcript)
        return dateOrPhoneDetector.matches(in: transcript, options: [], range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: transcript) else { return nil }
            return text.offset(of: range.lowerBound)..<text.offset(of: range.upperBound)
        }
    }
}
