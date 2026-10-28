@testable import CurrencySpot
import Foundation
import Testing

@Suite("CalculatorViewModel Keypad Tests")
struct CalculatorViewModelKeypadTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))

    private func makeViewModel() throws -> CalculatorViewModel {
        makeIsolatedCalculatorViewModel(defaults: try isolatedDefaults.make(), appState: appState)
    }

    private func calculate(_ keys: String, in viewModel: CalculatorViewModel) {
        for key in keys {
            switch key {
            case "0" ... "9": viewModel.press(.digit(Int(String(key)) ?? 0))
            case ".": viewModel.press(.decimalPoint)
            case "+": viewModel.press(.operation(.add))
            case "-": viewModel.press(.operation(.subtract))
            case "*": viewModel.press(.operation(.multiply))
            case "/": viewModel.press(.operation(.divide))
            case "=": viewModel.press(.equals)
            case "C": viewModel.press(.clear)
            default: Issue.record("Unknown key \(key)")
            }
        }
    }

    @Test("the amount keypad shifts digits in as cents and has no arithmetic")
    func amountKeypadKeys() throws {
        let viewModel = try makeViewModel()

        #expect(viewModel.press(.digit(1)) == .accepted)
        #expect(viewModel.press(.digit(2)) == .accepted)
        #expect(viewModel.press(.digit(5)) == .accepted)
        #expect(viewModel.press(.delete) == .deleted)
        #expect(viewModel.press(.operation(.add)) == .rejected)

        #expect(viewModel.inputAmountString == "12")
    }

    @Test("equals settles the calculation and reports it as settled")
    func equalsReportsSettled() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("8*3", in: viewModel)

        #expect(viewModel.press(.equals) == .settled)
        #expect(viewModel.calculationSteps == nil)
        #expect(viewModel.inputAmount == 24)
    }

    @Test("calculator keys update the From amount as each key lands")
    func calculatorKeysDriveAmount() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)

        calculate("1250+8*3", in: viewModel)

        #expect(viewModel.inputAmount == 1274)
    }

    @Test("switching to the calculator continues from the amount already typed")
    func calculatorStartsFromTypedAmount() throws {
        let viewModel = try makeViewModel()
        for digit in ["1", "2", "5", "0"] { viewModel.appendDigit(digit) }

        viewModel.showKeypad(.calculator)
        calculate("+1", in: viewModel)

        #expect(viewModel.inputAmount == Decimal(string: "13.5"))
    }

    @Test("steps appear once an operator is typed, only on the calculator keypad")
    func stepsNeedOperatorAndCalculatorKeypad() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)

        calculate("8", in: viewModel)
        #expect(viewModel.calculationSteps == nil)

        calculate("*3", in: viewModel)
        #expect(viewModel.calculationSteps == "8 × 3")

        viewModel.showKeypad(.amount)
        #expect(viewModel.calculationSteps == nil)
    }

    @Test("returning to the calculator resumes the steps while the amount is untouched")
    func returningResumesUntouchedSteps() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("8*3", in: viewModel)

        viewModel.showKeypad(.amount)
        viewModel.showKeypad(.calculator)
        #expect(viewModel.calculationSteps == "8 × 3")

        viewModel.showKeypad(.amount)
        viewModel.appendDigit("5")
        viewModel.showKeypad(.calculator)
        #expect(viewModel.calculationSteps == nil)
    }

    @Test("returning resumes steps that have no result yet, such as a division by zero")
    func returningResumesUndefinedSteps() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("5/0", in: viewModel)

        viewModel.showKeypad(.amount)
        viewModel.showKeypad(.calculator)

        #expect(viewModel.calculationSteps == "5 ÷ 0")
    }

    @Test("a key whose result outgrows the From field is rejected and leaves the amount alone")
    func oversizedResultIsRejected() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("999999999999*9", in: viewModel)
        #expect(viewModel.inputAmount == 8_999_999_999_991)

        let outcome = viewModel.press(.digit(9))

        #expect(outcome == .rejected)
        #expect(viewModel.inputAmount == 8_999_999_999_991)
        #expect(viewModel.calculationSteps?.hasSuffix("9") == true)
    }

    @Test("an amount sent from another tab returns to the amount keypad")
    func pendingConversionReturnsToAmountKeypad() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("8*3", in: viewModel)
        appState.pendingConversion = PendingConversion(baseCurrency: "JPY", targetCurrency: "USD", amountInput: "120000")

        viewModel.consumePendingConversion()

        #expect(viewModel.keypadMode == .amount)
        #expect(viewModel.calculationSteps == nil)
        #expect(viewModel.inputAmountString == "120000")
    }

    @Test("swapping currencies keeps the calculation going")
    func swapKeepsCalculation() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("8*3", in: viewModel)

        viewModel.swapCurrencies()

        #expect(viewModel.calculationSteps == "8 × 3")
        #expect(viewModel.inputAmount == 24)
    }

    @Test("dividing by zero flags the calculation as undefined until the divisor changes")
    func divisionByZeroIsFlagged() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("5/", in: viewModel)

        #expect(viewModel.press(.digit(0)) == .undefined)
        #expect(viewModel.isCalculationUndefined)
        #expect(viewModel.press(.decimalPoint) == .accepted)
        #expect(viewModel.isCalculationUndefined)

        #expect(viewModel.press(.digit(5)) == .accepted)
        #expect(viewModel.isCalculationUndefined == false)
        #expect(viewModel.inputAmount == 10)
    }

    @Test("the amount keypad never shows the calculation as undefined")
    func amountKeypadIsNeverUndefined() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("5/0", in: viewModel)

        viewModel.showKeypad(.amount)

        #expect(viewModel.isCalculationUndefined == false)
    }

    @Test("equals on a result below zero settles at the zero the field shows")
    func negativeResultSettlesAtZero() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)

        calculate("5-8=+10", in: viewModel)

        #expect(viewModel.inputAmount == 10)
    }

    @Test("a result below zero shows as zero")
    func negativeResultShowsZero() throws {
        let viewModel = try makeViewModel()
        viewModel.showKeypad(.calculator)

        calculate("5-8", in: viewModel)

        #expect(viewModel.inputAmount == 0)
    }
}
