@testable import CurrencySpot
import Foundation
import Testing

@Suite("CalculatorViewModel Clipboard Tests")
struct CalculatorViewModelClipboardTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))
    private let history: ConversionHistoryStore

    init() throws {
        history = ConversionHistoryStore(defaults: try isolatedDefaults.make())
    }

    private func makeViewModel() async throws -> CalculatorViewModel {
        let viewModel = makeIsolatedCalculatorViewModel(defaults: try isolatedDefaults.make(), appState: appState, history: history)
        await viewModel.fetchExchangeRates()
        return viewModel
    }

    private func calculate(_ keys: String, in viewModel: CalculatorViewModel) {
        for key in keys {
            switch key {
            case "0" ... "9": viewModel.press(.digit(Int(String(key)) ?? 0))
            case "+": viewModel.press(.operation(.add))
            case "/": viewModel.press(.operation(.divide))
            default: Issue.record("Unknown key \(key)")
            }
        }
    }

    @Test("pasting a number replaces the amount on the amount keypad")
    func pasteReplacesTypedAmount() async throws {
        let viewModel = try await makeViewModel()
        calculate("500", in: viewModel)

        #expect(viewModel.paste("1.234,56") == .accepted)

        #expect(viewModel.inputAmount == Decimal(string: "1234.56"))
        #expect(viewModel.keypadMode == .amount)
    }

    @Test("pasting on the calculator keypad drops the pending calculation and continues from the pasted amount")
    func pasteClearsPendingCalculation() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("12+3", in: viewModel)

        #expect(viewModel.paste("€ 7,50") == .accepted)
        #expect(viewModel.keypadMode == .calculator)
        #expect(viewModel.calculationSteps == nil)
        #expect(viewModel.inputAmount == Decimal(string: "7.5"))

        calculate("+1", in: viewModel)
        #expect(viewModel.inputAmount == Decimal(string: "8.5"))
    }

    @Test("text without a usable number is rejected and leaves the amount and calculation alone")
    func unusablePasteIsRejected() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("12+3", in: viewModel)

        #expect(viewModel.paste("Lunch") == .rejected)

        #expect(viewModel.inputAmount == 15)
        #expect(viewModel.calculationSteps == "12 + 3")
    }

    @Test("an amount longer than the From field holds is rejected")
    func pasteBeyondDigitCapIsRejected() async throws {
        let viewModel = try await makeViewModel()

        #expect(viewModel.paste("1234567890123.45") == .accepted)
        #expect(viewModel.paste("12345678901234.5") == .rejected)

        #expect(viewModel.inputAmount == Decimal(string: "1234567890123.45"))
    }

    @Test("a pasted amount is saved to history like a typed one")
    func pastedAmountIsSaved() async throws {
        let viewModel = try await makeViewModel()

        viewModel.paste("100 USD")
        viewModel.saveConversion()

        let record = try #require(history.records.first)
        #expect(record.amount == 100)
        #expect(record.calculation == nil)
    }

    @Test("copy offers the amounts as shown, without the currency code")
    func copyOffersShownAmounts() async throws {
        let viewModel = try await makeViewModel()
        calculate("123456", in: viewModel)

        #expect(viewModel.copyableInputAmount == viewModel.formattedInputAmount)
        #expect(viewModel.copyableConvertedAmount == viewModel.convertedAmount)
        #expect(viewModel.copyableInputAmount?.contains("USD") == false)
    }

    @Test("copy has nothing to offer for a division by zero")
    func copyIsUnavailableWhenUndefined() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)
        calculate("5/0", in: viewModel)

        #expect(viewModel.copyableInputAmount == nil)
        #expect(viewModel.copyableConvertedAmount == nil)
    }

    @Test("copy offers the From amount but not a converted amount when the pair has no rate")
    func copyWithoutPairRate() async throws {
        let viewModel = try await makeViewModel()
        viewModel.targetCurrency = "ZZZ"
        calculate("100", in: viewModel)

        #expect(viewModel.copyableInputAmount == viewModel.formattedInputAmount)
        #expect(viewModel.copyableConvertedAmount == nil)
    }
}
