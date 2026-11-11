import Foundation

nonisolated struct PastedAmountParser {
    let locale: Locale

    private static let decimalMarks: Set<Character> = [".", ","]
    private static let groupingMarks: Set<Character> = [" ", "\u{00A0}", "\u{202F}", "\u{2009}", "'", "\u{2019}"]
    private static let minusSigns: Set<Character> = ["-", "\u{2212}"]
    private static let posix = Locale(identifier: "en_US_POSIX")

    func amount(in text: String) -> Decimal? {
        let characters = Array(text)
        guard let first = characters.firstIndex(where: Self.isDigit),
              let last = characters.lastIndex(where: Self.isDigit)
        else { return nil }
        let prefix = characters[..<first]
        guard !prefix.contains(where: Self.minusSigns.contains),
              prefix.last.map(Self.decimalMarks.contains) != true
        else { return nil }
        guard let value = number(in: Array(characters[first...last])) else { return nil }
        let cents = Self.rounded(value)
        return cents > 0 ? cents : nil
    }

    private enum DecimalSeparator {
        case absent
        case at(Int)
        case contradictory
    }

    private func number(in core: [Character]) -> Decimal? {
        guard core.allSatisfy({ Self.isDigit($0) || Self.decimalMarks.contains($0) || Self.groupingMarks.contains($0) })
        else { return nil }
        let integerPart: [Character]
        let fraction: String
        switch decimalSeparator(in: core) {
        case .absent:
            (integerPart, fraction) = (core, "")
        case let .at(index):
            (integerPart, fraction) = (Array(core[..<index]), String(core[(index + 1)...]))
        case .contradictory:
            return nil
        }
        guard fraction.allSatisfy(Self.isDigit), let integerDigits = Self.integerDigits(in: integerPart) else { return nil }
        return Decimal(string: fraction.isEmpty ? integerDigits : "\(integerDigits).\(fraction)", locale: Self.posix)
    }

    private func decimalSeparator(in core: [Character]) -> DecimalSeparator {
        let marks = core.indices.filter { Self.decimalMarks.contains(core[$0]) }
        guard let lastMark = marks.last else { return .absent }
        let separator = core[lastMark]
        if Set(marks.map { core[$0] }).count == 2 {
            return marks.filter { core[$0] == separator }.count == 1 ? .at(lastMark) : .contradictory
        }
        guard marks.count == 1 else { return .absent }
        let fractionLength = core.count - lastMark - 1
        let integerIsZero = core[..<lastMark].allSatisfy { $0 == "0" }
        guard fractionLength == 3, !integerIsZero else { return .at(lastMark) }
        return String(separator) == locale.decimalSeparator ? .at(lastMark) : .absent
    }

    private static func integerDigits(in part: [Character]) -> String? {
        let separators = part.filter { !isDigit($0) }
        let groups: [String] = part
            .split(omittingEmptySubsequences: false) { !isDigit($0) }
            .map { String($0) }
        guard groups.count > 1 else { return groups.first }
        guard Set(separators).count == 1, isValidGrouping(groups, separator: separators[0]) else { return nil }
        return groups.joined()
    }

    private static func isValidGrouping(_ groups: [String], separator: Character) -> Bool {
        guard let head = groups.first, (1...3).contains(head.count) else { return false }
        let tail = groups.dropFirst()
        if tail.allSatisfy({ $0.count == 3 }) { return true }
        return separator == "," && tail.last?.count == 3 && tail.dropLast().allSatisfy { $0.count == 2 } && head.count <= 2
    }

    private static func isDigit(_ character: Character) -> Bool {
        ("0"..."9").contains(character)
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, 2, .plain)
        return result
    }
}
