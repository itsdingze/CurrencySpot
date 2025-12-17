//
//  NumberPadView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/27/25.
//

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

    var backgroundColor: Color {
        switch self {
        case .number:
            .secondaryBackground
        case .clear:
            .secondaryAccent.opacity(0.8)
        case .delete:
            .accentColor.opacity(0.8)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .number:
            .textPrimary
        case .clear, .delete:
            .white
        }
    }

    var accessibilityLabel: String {
        switch self {
        case let .number(value):
            "Number \(value)"
        case .clear:
            "Clear all"
        case .delete:
            "Delete last digit"
        }
    }

    var accessibilityHint: String {
        switch self {
        case let .number(value):
            "Adds \(value) to the amount"
        case .clear:
            "Clears the entire amount"
        case .delete:
            "Removes the last entered digit"
        }
    }

    var accessibilityInputLabels: [String] {
        switch self {
        case let .number(value):
            [value, "Number \(value)", "\(value) key"]
        case .clear:
            ["Clear", "C", "Clear all", "Reset"]
        case .delete:
            ["Delete", "Backspace", "Remove"]
        }
    }
}

struct NumberPadView: View {
    @Binding var inputValue: String
    let maxInputLength: Int = 15

    @State private var buttonPressed = false
    @State private var maxLengthReached = false
    @State private var clearPressed = false
    @State private var deletePressed = false

    private let buttonSpacing: CGFloat = 12
    private let rowSpacing: CGFloat = 12

    private let buttonLayout: [[NumberPadButton]] = [
        [.number("7"), .number("8"), .number("9")],
        [.number("4"), .number("5"), .number("6")],
        [.number("1"), .number("2"), .number("3")],
        [.clear, .number("0"), .delete],
    ]

    var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(Array(buttonLayout.enumerated()), id: \.offset) { _, row in
                HStack(spacing: buttonSpacing) {
                    ForEach(row) { button in
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
        .accessibilityLabel("Number pad")
        .accessibilityHint("Use to enter the amount to convert")
    }

    // MARK: - Private Views

    @ViewBuilder
    private func numberPadButton(_ button: NumberPadButton) -> some View {
        Button(action: { buttonTapped(button) }) {
            Text(button.label)
                .font(.system(.title, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundColor(button.foregroundColor)
        .background(button.backgroundColor)
        .clipShape(Capsule())
        .accessibilityLabel(button.accessibilityLabel)
        .accessibilityHint(button.accessibilityHint)
        .accessibilityInputLabels(button.accessibilityInputLabels)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Private Methods

    private func buttonTapped(_ button: NumberPadButton) {
        switch button {
        case let .number(value):
            handleNumberInput(value)
        case .clear:
            handleClear()
        case .delete:
            handleDelete()
        }
    }

    private func handleNumberInput(_ value: String) {
        guard inputValue.count < maxInputLength || inputValue == "0" else {
            maxLengthReached.toggle()
            return
        }

        buttonPressed.toggle()
        inputValue = inputValue == "0" ? value : inputValue + value
    }

    private func handleClear() {
        clearPressed.toggle()
        inputValue = "0"
    }

    private func handleDelete() {
        deletePressed.toggle()

        if inputValue.count > 1 {
            inputValue = String(inputValue.dropLast())
        } else {
            inputValue = "0"
        }
    }
}
