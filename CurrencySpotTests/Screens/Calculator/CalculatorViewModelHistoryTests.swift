@testable import CurrencySpot
import Foundation
import Testing

@Suite("CalculatorViewModel History Tests")
struct CalculatorViewModelHistoryTests {
    private static let start = Date(timeIntervalSince1970: 1_800_000_000)

    private let isolatedDefaults = IsolatedDefaults()
    private let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))
    private let history: ConversionHistoryStore
    private let clock = AdjustableDateProvider(Self.start)

    init() throws {
        history = ConversionHistoryStore(defaults: try isolatedDefaults.make())
    }

    private func makeViewModel(loadingRates: Bool = true) async throws -> CalculatorViewModel {
        let viewModel = makeIsolatedCalculatorViewModel(
            defaults: try isolatedDefaults.make(),
            appState: appState,
            history: history,
            dateProvider: clock
        )
        if loadingRates { await viewModel.fetchExchangeRates() }
        return viewModel
    }

    private func press(_ keys: String, in viewModel: CalculatorViewModel) {
        for key in keys {
            switch key {
            case "0" ... "9": viewModel.press(.digit(Int(String(key)) ?? 0))
            case "+": viewModel.press(.operation(.add))
            case "*": viewModel.press(.operation(.multiply))
            case "/": viewModel.press(.operation(.divide))
            case "=": viewModel.press(.equals)
            case "C": viewModel.press(.clear)
            default: Issue.record("Unknown key \(key)")
            }
        }
    }

    private func steps(of record: ConversionRecord?) -> String? {
        record?.calculation?.steps(locale: Locale(identifier: "en_US"))
    }

    private func formatted(_ amount: Decimal?) -> String? {
        amount?.formatted(.number.precision(.fractionLength(2)))
    }

    // MARK: - Equals

    @Test("equals saves the calculation with both currencies, the converted amount and the time")
    func equalsSavesCalculation() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)
        clock.advance(by: 60)

        press("8*3=", in: viewModel)

        let record = try #require(history.records.first)
        #expect(history.records.count == 1)
        #expect(steps(of: record) == "8 × 3")
        #expect(record.amount == 24)
        #expect(record.base == "USD")
        #expect(record.target == "EUR")
        #expect(formatted(record.converted) == viewModel.convertedAmount)
        #expect(record.date == Self.start.addingTimeInterval(60))
    }

    @Test("equals without an operator, without a result, or without a second number saves nothing")
    func equalsWithoutCalculationSavesNothing() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)

        press("8*3==", in: viewModel)
        press("5/0=", in: viewModel)
        press("C5*=", in: viewModel)

        #expect(history.records.count == 1)
    }

    // MARK: - Moving On

    @Test("moving on saves a typed amount without steps")
    func movingOnSavesTypedAmount() async throws {
        let viewModel = try await makeViewModel()
        press("10000", in: viewModel)

        viewModel.saveConversion()

        let record = try #require(history.records.first)
        #expect(record.calculation == nil)
        #expect(record.amount == 100)
        #expect(formatted(record.converted) == viewModel.convertedAmount)
    }

    @Test("moving on mid-calculation saves the calculation shown so far")
    func movingOnSavesLiveCalculation() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)
        press("8*3", in: viewModel)

        viewModel.saveConversion()

        #expect(steps(of: history.records.first) == "8 × 3")
        #expect(history.records.first?.amount == 24)
    }

    @Test("moving on again, or right after equals, saves no second copy")
    func movingOnSavesNoDuplicate() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)
        press("8*3==", in: viewModel)

        viewModel.saveConversion()
        viewModel.showKeypad(.amount)
        viewModel.saveConversion()

        #expect(history.records.count == 1)
    }

    @Test("a changed currency counts as a new conversion")
    func changedCurrencySavesAgain() async throws {
        let viewModel = try await makeViewModel()
        press("10000", in: viewModel)
        viewModel.saveConversion()

        viewModel.targetCurrency = "JPY"
        viewModel.saveConversion()

        #expect(history.records.map(\.target) == ["JPY", "EUR"])
    }

    @Test("zero, a division by zero, missing rates and sample rates are never saved")
    func unsavableConversions() async throws {
        let viewModel = try await makeViewModel()
        viewModel.saveConversion()
        viewModel.showKeypad(.calculator)
        press("5/0", in: viewModel)
        viewModel.saveConversion()

        let withoutRates = try await makeViewModel(loadingRates: false)
        press("10000", in: withoutRates)
        withoutRates.saveConversion()

        let withSampleRates = try await makeViewModel(loadingRates: false)
        withSampleRates.showSampleRates()
        press("10000", in: withSampleRates)
        withSampleRates.saveConversion()

        let withoutPairRate = try await makeViewModel()
        withoutPairRate.targetCurrency = "ZZZ"
        press("10000", in: withoutPairRate)
        withoutPairRate.saveConversion()

        #expect(history.records.isEmpty)
    }

    @Test("clearing saves an amount left on screen for two seconds, not a quick correction")
    func clearSavesSettledAmountOnly() async throws {
        let viewModel = try await makeViewModel()
        press("12", in: viewModel)
        clock.advance(by: 1)
        press("C", in: viewModel)
        #expect(history.records.isEmpty)

        press("10000", in: viewModel)
        clock.advance(by: 2)
        press("C", in: viewModel)

        #expect(history.records.map(\.amount) == [100])
    }

    // MARK: - Switching Currencies

    @Test("switching currencies saves the pair left on screen for two seconds")
    func switchingSavesSettledPair() async throws {
        let viewModel = try await makeViewModel()
        press("10000", in: viewModel)
        clock.advance(by: 2)

        viewModel.targetCurrency = "GBP"

        #expect(history.records.map(\.target) == ["EUR"])
    }

    @Test("a pair switched away from within two seconds is a correction and is not saved")
    func quickSwitchSavesNothing() async throws {
        let viewModel = try await makeViewModel()
        press("10000", in: viewModel)
        clock.advance(by: 2)
        viewModel.targetCurrency = "GBP"
        clock.advance(by: 1)

        viewModel.targetCurrency = "JPY"

        #expect(history.records.map(\.target) == ["EUR"])
    }

    @Test("picking the currency already shown is not a switch and saves nothing")
    func repickingSameCurrencySavesNothing() async throws {
        let viewModel = try await makeViewModel()
        press("10000", in: viewModel)
        clock.advance(by: 2)

        viewModel.targetCurrency = "EUR"
        viewModel.baseCurrency = "USD"

        #expect(history.records.isEmpty)
    }

    @Test("swapping saves the pair before the swap once")
    func swappingSavesPairBeforeSwap() async throws {
        let viewModel = try await makeViewModel()
        press("10000", in: viewModel)
        clock.advance(by: 2)

        viewModel.swapCurrencies()

        #expect(history.records.map { "\($0.base)→\($0.target)" } == ["USD→EUR"])
    }

    @Test("an operator that leaves the amount unchanged does not restart the two seconds")
    func operatorKeepsAmountShownTime() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)
        press("100", in: viewModel)
        clock.advance(by: 3)
        press("+", in: viewModel)
        clock.advance(by: 1)

        press("C", in: viewModel)

        #expect(history.records.map(\.amount) == [100])
    }

    @Test("a conversion between the same currency is not saved")
    func sameCurrencyIsNotSaved() async throws {
        let viewModel = try await makeViewModel()
        viewModel.targetCurrency = "USD"
        press("10000", in: viewModel)

        viewModel.saveConversion()

        #expect(history.records.isEmpty)
    }

    @Test("an amount sent from the camera saves the amount it replaces")
    func pendingConversionSavesReplacedAmount() async throws {
        let viewModel = try await makeViewModel()
        press("10000", in: viewModel)
        appState.pendingConversion = PendingConversion(baseCurrency: "JPY", targetCurrency: "USD", amountInput: "120000")

        viewModel.consumePendingConversion()

        #expect(history.records.map(\.amount) == [100])
        #expect(viewModel.inputAmountString == "120000")
    }

    @Test("opening history saves the conversion on screen first")
    func openingHistorySaves() async throws {
        let viewModel = try await makeViewModel()
        press("10000", in: viewModel)

        viewModel.showHistory()

        #expect(history.records.map(\.amount) == [100])
        #expect(viewModel.destination == .history)
    }

    // MARK: - Restoring

    @Test("restoring a calculation brings back its currencies and steps on the calculator keypad")
    func restoreCalculation() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)
        press("8*3=", in: viewModel)
        let record = try #require(history.records.first)
        viewModel.baseCurrency = "JPY"
        viewModel.targetCurrency = "GBP"
        viewModel.showKeypad(.amount)
        viewModel.clearInput()

        viewModel.restore(record)

        #expect(viewModel.keypadMode == .calculator)
        #expect(viewModel.calculationSteps == "8 × 3")
        #expect(viewModel.inputAmount == 24)
        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.targetCurrency == "EUR")
    }

    @Test("restoring a typed amount keeps the keypad and shows no steps")
    func restoreTypedAmount() async throws {
        let viewModel = try await makeViewModel()
        press("10000", in: viewModel)
        viewModel.saveConversion()
        let record = try #require(history.records.first)
        viewModel.showKeypad(.calculator)
        press("8*3", in: viewModel)

        viewModel.restore(record)

        #expect(viewModel.keypadMode == .calculator)
        #expect(viewModel.calculationSteps == nil)
        #expect(viewModel.inputAmount == 100)
    }

    @Test("moving on from a restored conversion saves no copy of it")
    func restoredConversionIsNotSavedAgain() async throws {
        let viewModel = try await makeViewModel()
        viewModel.showKeypad(.calculator)
        press("8*3=", in: viewModel)
        press("C", in: viewModel)
        let record = try #require(history.records.first)
        history.add(ConversionRecord(
            id: UUID(),
            calculation: nil,
            amount: 5,
            base: "USD",
            target: "EUR",
            converted: 4.47,
            date: Self.start
        ))

        viewModel.restore(record)
        viewModel.saveConversion()

        #expect(history.records.count == 2)
    }
}
