import Foundation

struct NumberShape {
    enum Kind {
        case integer
        case grouped
        case money
        case oneDecimal
        case otherDecimal
        case multiplied
        case malformed
    }

    let kind: Kind
    let amount: Decimal?
    let integerDigitCount: Int

    init(_ token: NumberToken, fractionDigits: Int) {
        if let multiplied = token.multipliedAmount {
            self.init(kind: .multiplied, amount: multiplied, integerDigitCount: 0)
            return
        }
        let decimalIndex = Self.decimalSeparatorIndex(in: token, fractionDigits: fractionDigits)
        let integerGroups = decimalIndex.map { Array(token.groups.prefix($0 + 1)) } ?? token.groups
        let integerSeparators = decimalIndex.map { Array(token.separators.prefix($0)) } ?? token.separators
        let fraction = decimalIndex.map { token.groups[$0 + 1] } ?? ""
        let integerDigits = integerGroups.joined()

        guard Self.isValidGrouping(integerGroups, separators: integerSeparators),
              !Self.hasLeadingZero(integerDigits)
        else {
            self.init(kind: .malformed, amount: nil, integerDigitCount: 0)
            return
        }
        let kind: Kind = switch fraction.count {
        case 0: integerGroups.count > 1 ? .grouped : .integer
        case 1: .oneDecimal
        case 2, fractionDigits: .money
        default: .otherDecimal
        }
        self.init(
            kind: kind,
            amount: Decimal(string: fraction.isEmpty ? integerDigits : "\(integerDigits).\(fraction)"),
            integerDigitCount: integerDigits.count
        )
    }

    private init(kind: Kind, amount: Decimal?, integerDigitCount: Int) {
        self.kind = kind
        self.amount = amount
        self.integerDigitCount = integerDigitCount
    }

    var isMoneyShaped: Bool {
        kind == .money || kind == .grouped
    }

    private static func decimalSeparatorIndex(in token: NumberToken, fractionDigits: Int) -> Int? {
        guard let last = token.separators.last, last == "." || last == "," else { return nil }
        let punctuation = token.separators.filter { $0 == "." || $0 == "," }
        let lastIndex = token.separators.count - 1
        if Set(punctuation).count == 2 { return lastIndex }
        guard punctuation.count == 1, let fraction = token.groups.last else { return nil }
        switch fraction.count {
        case 1...2: return lastIndex
        case 3 where token.groups.first == "0": return lastIndex
        case 3 where fractionDigits == 3 && last == ".": return lastIndex
        default: return nil
        }
    }

    private static func hasLeadingZero(_ integerDigits: String) -> Bool {
        integerDigits.count > 1 && integerDigits.hasPrefix("0")
    }

    private static func isValidGrouping(_ groups: [String], separators: [Character]) -> Bool {
        guard groups.count > 1 else { return true }
        guard Set(separators).count == 1, let head = groups.first, (1...3).contains(head.count),
              !hasLeadingZero(head)
        else { return false }
        let tail = groups.dropFirst()
        if tail.allSatisfy({ $0.count == 3 }) { return true }
        return separators.first == "," && tail.last?.count == 3 && tail.dropLast().allSatisfy { $0.count == 2 }
    }
}
