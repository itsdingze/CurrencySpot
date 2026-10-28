import SwiftUI

extension CalculatorViewModel.KeypadMode {
    var title: LocalizedStringResource {
        switch self {
        case .amount: .calculatorModeBasic
        case .calculator: .calculatorModeCalculator
        }
    }

    var icon: Image {
        switch self {
        case .amount: Image(systemName: "arrow.left.arrow.right")
        case .calculator: Image(.keypadOperators)
        }
    }

    static func switchAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .appQuickFade : .smooth(duration: 0.4)
    }
}
