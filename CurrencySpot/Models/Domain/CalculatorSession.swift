import Foundation

nonisolated struct CalculatorSession: Equatable, Sendable {
    enum Mode: Hashable, CaseIterable, Sendable {
        case amount
        case calculator
    }

    enum KeyPress: Equatable, Sendable {
        case accepted
        case deleted
        case settled
        case undefined
        case rejected
    }

    struct Outcome {
        let press: KeyPress
        fileprivate(set) var amountDigits: String?
        fileprivate(set) var calculation: (expression: CalculatorExpression, result: Decimal)?

        fileprivate static let rejected = Outcome(press: .rejected)
    }

    private(set) var mode = Mode.amount
    private var expression = CalculatorExpression()
    private var settledCalculation: CalculatorExpression?
    private var amountDigits: String?

    var isUndefined: Bool {
        mode == .calculator && expression.result == nil
    }

    func steps(locale: Locale) -> String? {
        guard mode == .calculator, expression.hasOperator else { return nil }
        return expression.steps(locale: locale)
    }

    func calculation(forAmountDigits digits: String) -> CalculatorExpression? {
        guard amountDigits == digits else { return nil }
        guard expression.hasOperator else { return settledCalculation }
        return expression.isComplete && expression.result != nil ? expression : nil
    }

    mutating func show(_ newMode: Mode, fromAmount amount: Decimal, fromDigits digits: String) {
        let isResumable = expression.hasOperator && amountDigits == digits
        if newMode == .calculator, mode == .amount, !isResumable {
            expression = CalculatorExpression(settledAt: amount)
            settledCalculation = nil
            amountDigits = digits
        }
        mode = newMode
    }

    mutating func press(
        _ key: CalculatorExpression.Input,
        toAmountDigits: (Decimal) -> String,
        maxAmountDigits: Int
    ) -> Outcome {
        let wasUndefined = isUndefined
        let calculation = expression
        var next = expression
        guard next.apply(key) else { return .rejected }
        if key == .equals, let settled = next.result, settled < 0 {
            next = CalculatorExpression(settledAt: 0)
        }
        let digits = next.result.map(toAmountDigits)
        if let digits, digits.count > maxAmountDigits { return .rejected }

        if next != expression { settledCalculation = nil }
        expression = next
        if let digits { amountDigits = digits }
        var outcome = Outcome(press: pressKind(for: key, wasUndefined: wasUndefined), amountDigits: digits)
        if key == .equals, calculation.hasOperator, calculation.isComplete, let result = next.result {
            outcome.calculation = (calculation, result)
            settledCalculation = calculation
        }
        return outcome
    }

    mutating func restore(_ calculation: CalculatorExpression?, amount: Decimal, amountDigits digits: String) {
        if let calculation {
            mode = .calculator
            expression = calculation
        } else {
            expression = CalculatorExpression(settledAt: amount)
        }
        settledCalculation = nil
        amountDigits = digits
    }

    mutating func reset() {
        self = CalculatorSession()
    }

    private func pressKind(for key: CalculatorExpression.Input, wasUndefined: Bool) -> KeyPress {
        if isUndefined, !wasUndefined { return .undefined }
        switch key {
        case .delete: return .deleted
        case .equals: return .settled
        default: return .accepted
        }
    }
}
