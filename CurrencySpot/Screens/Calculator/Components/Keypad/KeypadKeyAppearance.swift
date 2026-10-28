import SwiftUI

extension KeypadKey.Role {
    var glyph: String {
        switch self {
        case let .digit(digit): "\(digit)"
        case .decimalPoint: Locale.autoupdatingCurrent.decimalSeparator ?? "."
        case .clear: "C"
        case .delete: "⌫"
        case .percent: "%"
        case let .operation(op): op.symbol
        case .equals: "="
        }
    }

    func fill(accent: Color) -> Color {
        switch self {
        case .digit, .decimalPoint: .secondaryBackground
        case .clear: .secondaryAccent.opacity(0.8)
        case .delete, .operation, .equals: accent.opacity(0.8)
        case .percent: Color.secondary.opacity(0.25)
        }
    }

    var foreground: Color {
        switch self {
        case .digit, .decimalPoint, .percent: .primary
        case .clear, .delete, .operation, .equals: .white
        }
    }

    func accessibilityLabel(
        in mode: CalculatorViewModel.KeypadMode,
        locale: Locale = .autoupdatingCurrent
    ) -> LocalizedStringResource {
        switch self {
        case let .digit(digit): .calculatorNumberPadDigitAccessibilityLabel(digit: "\(digit)")
        case .decimalPoint where locale.decimalSeparator == ",": .calculatorNumberPadDecimalCommaAccessibilityLabel
        case .decimalPoint: .calculatorNumberPadDecimalPointAccessibilityLabel
        case .clear: .calculatorNumberPadClearAccessibilityLabel
        case .delete where mode == .calculator: .calculatorNumberPadCalculatorDeleteAccessibilityLabel
        case .delete: .calculatorNumberPadDeleteAccessibilityLabel
        case .percent: .calculatorNumberPadPercentAccessibilityLabel
        case .operation(.add): .calculatorNumberPadAddAccessibilityLabel
        case .operation(.subtract): .calculatorNumberPadSubtractAccessibilityLabel
        case .operation(.multiply): .calculatorNumberPadMultiplyAccessibilityLabel
        case .operation(.divide): .calculatorNumberPadDivideAccessibilityLabel
        case .equals: .calculatorNumberPadEqualsAccessibilityLabel
        }
    }

    func accessibilityInputLabels(in mode: CalculatorViewModel.KeypadMode) -> [Text] {
        switch self {
        case .delete: [Text(accessibilityLabel(in: mode))]
        default: [Text(verbatim: glyph), Text(accessibilityLabel(in: mode))]
        }
    }
}
