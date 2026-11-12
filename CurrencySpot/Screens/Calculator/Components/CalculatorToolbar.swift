import SwiftUI

struct CalculatorToolbar: ToolbarContent {
    let viewModel: CalculatorViewModel
    let reduceMotion: Bool

    private var modeSelection: Binding<CalculatorViewModel.KeypadMode> {
        Binding { viewModel.keypadMode } set: { mode in
            withAnimation(CalculatorViewModel.KeypadMode.switchAnimation(reduceMotion: reduceMotion)) {
                viewModel.showKeypad(mode)
            }
        }
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { viewModel.showHistory() } label: {
                Label(.calculatorHistoryAccessibilityLabel, systemImage: "clock")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker(selection: modeSelection) {
                    ForEach(CalculatorViewModel.KeypadMode.allCases, id: \.self) { mode in
                        Label { Text(mode.title) } icon: { mode.icon }
                            .tag(mode)
                    }
                } label: {
                    Text(.calculatorNumberPadAccessibilityLabel)
                }
            } label: {
                Label {
                    Text(.calculatorNumberPadAccessibilityLabel)
                } icon: {
                    viewModel.keypadMode.icon
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .accessibilityValue(Text(viewModel.keypadMode.title))
        }
    }
}
