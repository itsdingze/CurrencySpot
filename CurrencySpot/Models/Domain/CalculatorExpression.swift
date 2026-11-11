import Foundation

nonisolated struct CalculatorExpression: Codable, Equatable, Sendable {
    enum Operator: Codable, Equatable, Sendable {
        case add
        case subtract
        case multiply
        case divide

        var symbol: String {
            switch self {
            case .add: "+"
            case .subtract: "−"
            case .multiply: "×"
            case .divide: "÷"
            }
        }
    }

    enum Input: Equatable, Sendable {
        case digit(Int)
        case decimalPoint
        case percent
        case operation(Operator)
        case delete
        case clear
        case equals

        fileprivate var isDigit: Bool {
            if case .digit = self { return true }
            return false
        }
    }

    private var operands = ["0"]
    private var operators: [Operator] = []
    private var isSettled = false

    private enum CodingKeys: String, CodingKey {
        case operands
        case operators
        case isSettled
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operands = try container.decode([String].self, forKey: .operands)
        operators = try container.decode([Operator].self, forKey: .operators)
        isSettled = try container.decode(Bool.self, forKey: .isSettled)
        guard !operands.isEmpty, operands.count == operators.count + 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .operands,
                in: container,
                debugDescription: "Each operator needs a number on both sides."
            )
        }
    }

    init(settledAt amount: Decimal) {
        operands = [NSDecimalNumber(decimal: amount).description(withLocale: Self.posix)]
        isSettled = true
    }

    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let percentSign = "%"
    private static let maxDigitsPerNumber = 12
    private static let maxFractionDigits = 2

    var hasOperator: Bool { !operators.isEmpty }

    var isComplete: Bool { operands.last?.isEmpty == false }

    var result: Decimal? {
        var pendingOperands = operands
        var pendingOperators = operators
        if pendingOperands.last?.isEmpty == true {
            pendingOperands.removeLast()
            pendingOperators.removeLast()
        }
        return Self.evaluate(pendingOperands, pendingOperators)
    }

    func steps(locale: Locale) -> String {
        var parts: [String] = []
        for (index, operand) in operands.enumerated() {
            if !operand.isEmpty { parts.append(Self.display(operand, locale: locale)) }
            if index < operators.count { parts.append(operators[index].symbol) }
        }
        return parts.joined(separator: " ")
    }

    @discardableResult
    mutating func apply(_ input: Input) -> Bool {
        if isSettled {
            isSettled = false
            if input == .decimalPoint || input.isDigit { self = CalculatorExpression() }
        }
        let current = operands[operands.count - 1]
        switch input {
        case let .digit(digit):
            guard !current.hasSuffix(Self.percentSign),
                  current.filter(\.isNumber).count < Self.maxDigitsPerNumber,
                  Self.fractionDigitCount(in: current) < Self.maxFractionDigits
            else { return false }
            operands[operands.count - 1] = current == "0" ? "\(digit)" : current + "\(digit)"
        case .decimalPoint:
            guard !current.contains("."), !current.hasSuffix(Self.percentSign) else { return false }
            operands[operands.count - 1] = current.isEmpty ? "0." : current + "."
        case .percent:
            guard !current.isEmpty,
                  !current.hasSuffix(Self.percentSign),
                  hasOperator || Self.number(in: current)?.value != 0
            else { return false }
            operands[operands.count - 1] = current + Self.percentSign
        case let .operation(op):
            if current.isEmpty {
                operators[operators.count - 1] = op
            } else {
                operators.append(op)
                operands.append("")
            }
        case .delete:
            if current.isEmpty, !operators.isEmpty {
                operators.removeLast()
                operands.removeLast()
            } else if current.count > 1 {
                operands[operands.count - 1] = String(current.dropLast())
            } else {
                operands[operands.count - 1] = operators.isEmpty ? "0" : ""
            }
        case .clear:
            self = CalculatorExpression()
        case .equals:
            guard let result else { return false }
            self = CalculatorExpression(settledAt: Self.rounded(result, scale: 2))
        }
        return true
    }

    // MARK: - Evaluation

    private static func evaluate(_ operands: [String], _ operators: [Operator]) -> Decimal? {
        guard operands.count == operators.count + 1,
              let first = number(in: operands[0])
        else { return nil }

        var finishedTerms: Decimal = 0
        var termSign: Decimal = 1
        var term = first.isPercent ? first.value / 100 : first.value
        for (op, operand) in zip(operators, operands.dropFirst()) {
            guard let (value, isPercent) = number(in: operand) else { return nil }
            switch op {
            case .multiply:
                term *= isPercent ? value / 100 : value
            case .divide:
                let divisor = isPercent ? value / 100 : value
                if divisor == 0 { return nil }
                term /= divisor
            case .add, .subtract:
                let runningTotal = finishedTerms + termSign * term
                finishedTerms = runningTotal
                termSign = op == .add ? 1 : -1
                term = isPercent ? runningTotal * value / 100 : value
            }
        }
        return finishedTerms + termSign * term
    }

    private static func fractionDigitCount(in operand: String) -> Int {
        guard let point = operand.firstIndex(of: ".") else { return 0 }
        return operand[operand.index(after: point)...].count
    }

    private static func number(in operand: String) -> (value: Decimal, isPercent: Bool)? {
        let isPercent = operand.hasSuffix(percentSign)
        let digits = isPercent ? String(operand.dropLast()) : operand
        guard let value = Decimal(string: digits, locale: posix) else { return nil }
        return (value, isPercent)
    }

    private static func display(_ operand: String, locale: Locale) -> String {
        let isPercent = operand.hasSuffix(percentSign)
        let number = isPercent ? String(operand.dropLast()) : operand
        let pieces = number.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Decimal(string: String(pieces[0]), locale: posix) ?? 0
        var text = whole.formatted(.number.locale(locale).precision(.fractionLength(0)))
        if pieces.count > 1 { text += (locale.decimalSeparator ?? ".") + pieces[1] }
        return isPercent ? text + percentSign : text
    }

    private static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
