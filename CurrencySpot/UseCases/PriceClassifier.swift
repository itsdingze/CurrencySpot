//
//  PriceClassifier.swift
//  CurrencySpot
//

import Foundation

struct PriceClassification: Equatable, Sendable {
    let amount: Decimal
    let isPrice: Bool
}

struct PriceClassifier: Sendable {
    private static let currencySymbols = Set("$€£¥₩₹฿₫₺₪")

    private static let numberToken = /[0-9]+(?:[.,][0-9]+)*/

    private static let dateDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    func classify(_ transcript: String) -> PriceClassification? {
        let matches = transcript.matches(of: Self.numberToken)
        guard !matches.isEmpty else { return nil }

        let match = matches.first { $0.output.contains(",") || $0.output.contains(".") } ?? matches[0]
        let token = match.output
        guard let amount = Self.parseAmount(String(token)) else { return nil }

        let hasCurrencySymbol = Self.containsCurrencyMarker(transcript)
        let isPriceShaped = token.contains(",") || token.contains(".")
        let isRuledOut = Self.isPartOfDate(match.range, in: transcript)
            || Self.hasUnitSuffix(after: match.range, in: transcript)
        let isPrice = !isRuledOut && (hasCurrencySymbol || isPriceShaped)
        return PriceClassification(amount: amount, isPrice: isPrice)
    }

    private static let cjkCurrencyMarkers = Set("円元원")
    private static let isoCurrencyCodes = Set(Locale.commonISOCurrencyCodes)

    private static func containsCurrencyMarker(_ transcript: String) -> Bool {
        if transcript.contains(where: { currencySymbols.contains($0) || cjkCurrencyMarkers.contains($0) }) {
            return true
        }
        return transcript
            .split(whereSeparator: { !$0.isLetter })
            .contains { $0.count == 3 && $0.allSatisfy(\.isUppercase) && isoCurrencyCodes.contains(String($0)) }
    }

    private static let unitSuffixes: Set<String> = [
        "kg", "g", "mg", "lb", "lbs", "oz", "km", "m", "cm", "mm", "mi",
        "ml", "l", "kcal", "cal", "ghz", "mhz", "hz", "mph", "kwh", "w", "v",
    ]

    private static func hasUnitSuffix(after tokenRange: Range<String.Index>, in transcript: String) -> Bool {
        guard tokenRange.upperBound < transcript.endIndex else { return false }
        let next = transcript[tokenRange.upperBound]
        if next == "°" || next == "%" { return true }
        let word = transcript.suffix(from: tokenRange.upperBound).prefix(while: \.isLetter)
        return unitSuffixes.contains(word.lowercased())
    }

    private static func isPartOfDate(_ tokenRange: Range<String.Index>, in transcript: String) -> Bool {
        guard let dateDetector else { return false }
        let fullRange = NSRange(transcript.startIndex..., in: transcript)
        return dateDetector.matches(in: transcript, options: [], range: fullRange).contains { match in
            guard let matchRange = Range(match.range, in: transcript) else { return false }
            return matchRange.overlaps(tokenRange)
        }
    }

    /// Resolves "," and "." per token shape: "1,200" → 1200, "12,50" → 12.5, "1.234,56" → 1234.56.
    private static func parseAmount(_ token: String) -> Decimal? {
        let separators = token.filter { $0 == "," || $0 == "." }
        guard let lastSeparator = separators.last,
              let separatorIndex = token.lastIndex(of: lastSeparator)
        else { return Decimal(string: token) }

        // The last separator is decimal when the token mixes two separator kinds
        // ("1.234,56"), or has a single separator with 1–2 trailing digits ("12,50").
        // Otherwise every separator is grouping ("1,200", "1,200,300").
        let fraction = token.suffix(from: separatorIndex).dropFirst().filter(\.isNumber)
        let isDecimalSeparator = Set(separators).count == 2
            || (separators.count == 1 && (1...2).contains(fraction.count))
        guard isDecimalSeparator else { return Decimal(string: token.filter(\.isNumber)) }

        let whole = token.prefix(upTo: separatorIndex).filter(\.isNumber)
        return Decimal(string: "\(whole).\(fraction)")
    }
}
