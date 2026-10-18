import SwiftUI

private enum NumberPadButton: Identifiable, Equatable {
    case number(String)
    case clear
    case delete

    var id: String {
        switch self {
        case let .number(value):
            value
        case .clear:
            "C"
        case .delete:
            "⌫"
        }
    }

    var label: String {
        switch self {
        case let .number(value):
            value
        case .clear:
            "C"
        case .delete:
            "⌫"
        }
    }

    func backgroundColor(accent: Color) -> Color {
        switch self {
        case .number:
            .secondaryBackground
        case .clear:
            .secondaryAccent.opacity(0.8)
        case .delete:
            accent.opacity(0.8)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .number:
            .primary
        case .clear, .delete:
            .white
        }
    }

    var accessibilityLabel: LocalizedStringResource {
        switch self {
        case let .number(value):
            .calculatorNumberPadDigitAccessibilityLabel(digit: value)
        case .clear:
            .calculatorNumberPadClearAccessibilityLabel
        case .delete:
            .calculatorNumberPadDeleteAccessibilityLabel
        }
    }

    var accessibilityInputLabels: [Text] {
        switch self {
        case .number, .clear:
            [Text(verbatim: label), Text(accessibilityLabel)]
        case .delete:
            [Text(accessibilityLabel)]
        }
    }

}

struct NumberPadView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel
    @Environment(\.appAccent) private var accent

    @State private var buttonPressed = false
    @State private var maxLengthReached = false
    @State private var clearPressed = false
    @State private var deletePressed = false

    private let buttonLayout: [[NumberPadButton]] = [
        [.number("7"), .number("8"), .number("9")],
        [.number("4"), .number("5"), .number("6")],
        [.number("1"), .number("2"), .number("3")],
        [.clear, .number("0"), .delete],
    ]

    var body: some View {
        VStack(spacing: Spacing.element) {
            ForEach(buttonLayout.indices, id: \.self) { rowIndex in
                HStack(spacing: Spacing.element) {
                    ForEach(buttonLayout[rowIndex]) { button in
                        numberPadButton(button)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: buttonPressed)
        .sensoryFeedback(.warning, trigger: maxLengthReached)
        .sensoryFeedback(.selection, trigger: clearPressed)
        .sensoryFeedback(.decrease, trigger: deletePressed)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(.calculatorNumberPadAccessibilityLabel)
    }

    // MARK: - Private Views

    private func numberPadButton(_ button: NumberPadButton) -> some View {
        Button(button.label) { buttonTapped(button) }
            .buttonStyle(.numberPadKey(fill: button.backgroundColor(accent: accent), foreground: button.foregroundColor))
            .accessibilityLabel(button.accessibilityLabel)
            .accessibilityInputLabels(button.accessibilityInputLabels)
    }

    // MARK: - Private Methods

    private func buttonTapped(_ button: NumberPadButton) {
        switch button {
        case let .number(value):
            if calculatorViewModel.appendDigit(value) {
                buttonPressed.toggle()
            } else {
                maxLengthReached.toggle()
            }
        case .clear:
            clearPressed.toggle()
            calculatorViewModel.clearInput()
        case .delete:
            deletePressed.toggle()
            calculatorViewModel.deleteLastDigit()
        }
    }
}

#if DEBUG
#Preview {
    NumberPadView()
        .withDependencyContainer(.preview())
        .frame(height: 400)
        .padding()
}
#endif
