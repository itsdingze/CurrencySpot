//
//  PriceClassifier.swift
//  CurrencySpot
//

import Foundation

struct PriceClassification: Equatable, Sendable {
    let amount: Decimal
    let isPrice: Bool
}

/// MainActor (via default isolation), which the non-Sendable compiled `Regex`
/// statics rely on; all callers (camera scan pipeline) live on the main actor.
struct PriceClassifier {
    private static let currencySymbols = Set("$€£¥₩₹฿₫₺₪")

    private static let numberToken = /[0-9]+(?:[.,][0-9]+)*/

    private static let dateOrPhoneDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
            | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
    )

    /// nil means the number is noise (date, phone, unit, identifier) and gets
    /// no outline at all; isPrice false keeps the outline for tap-to-convert.
    func classify(_ transcript: String) -> PriceClassification? {
        let matches = transcript.matches(of: Self.numberToken)
        guard !matches.isEmpty else { return nil }

        let match = matches.first { $0.output.contains(",") || $0.output.contains(".") } ?? matches[0]
        let token = match.output
        guard let amount = Self.parseAmount(String(token)) else { return nil }

        // A currency marker overrides every noise rule.
        if Self.containsCurrencyMarker(transcript) {
            return PriceClassification(amount: amount, isPrice: true)
        }
        guard !Self.isNoise(match.range, token: token, in: transcript) else { return nil }
        let isPriceShaped = token.contains(",") || token.contains(".")
        return PriceClassification(amount: amount, isPrice: isPriceShaped)
    }

    // MARK: - Noise Rules

    /// Patterns that are essentially never prices: dates and phone numbers,
    /// unit measurements, barcode-length digit runs, and tokens glued to
    /// identifier characters (SN12345, 4006-100-0000, 16:9).
    private static func isNoise(
        _ range: Range<String.Index>,
        token: Substring,
        in transcript: String
    ) -> Bool {
        isDateOrPhoneNumber(range, in: transcript)
            || hasUnitSuffix(after: range, in: transcript)
            || isBareDigitRun(token)
            || isGluedToIdentifier(range, in: transcript)
    }

    /// Real-world bare prices top out around 6 digits (150000 IDR);
    /// anything longer without separators is a barcode or serial.
    private static func isBareDigitRun(_ token: Substring) -> Bool {
        token.count >= 7 && token.allSatisfy(\.isNumber)
    }

    private static func isGluedToIdentifier(_ range: Range<String.Index>, in transcript: String) -> Bool {
        isGlued(before: range.lowerBound, in: transcript) || isGlued(after: range.upperBound, in: transcript)
    }

    /// Letter prefixes (SN12345), colons (16:9), and digit-hyphen joints
    /// (4006-100) mark identifiers. A leading minus alone does not.
    private static func isGlued(before index: String.Index, in transcript: String) -> Bool {
        guard index > transcript.startIndex else { return false }
        let previous = transcript.index(before: index)
        let character = transcript[previous]
        if character.isASCII, character.isLetter { return true }
        if character == ":" { return true }
        guard character == "-", previous > transcript.startIndex else { return false }
        return transcript[transcript.index(before: previous)].isNumber
    }

    private static func isGlued(after index: String.Index, in transcript: String) -> Bool {
        guard index < transcript.endIndex else { return false }
        let character = transcript[index]
        if character == ":" { return true }
        guard character == "-" else { return false }
        let next = transcript.index(after: index)
        return next < transcript.endIndex && transcript[next].isNumber
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

    private static func isDateOrPhoneNumber(_ tokenRange: Range<String.Index>, in transcript: String) -> Bool {
        guard let dateOrPhoneDetector else { return false }
        let fullRange = NSRange(transcript.startIndex..., in: transcript)
        return dateOrPhoneDetector.matches(in: transcript, options: [], range: fullRange).contains { match in
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
