@testable import CurrencySpot
import Testing

struct ConverterChartViewModelTests {
    @Test("the chart beside the converter shows the pair being converted")
    func chartShowsTheConvertedPair() throws {
        let viewModel = try makeViewModel()

        let chart = viewModel.chart(base: "CHF", target: "GBP")

        #expect(chart.baseCurrency == "CHF")
        #expect(chart.targetCurrency == "GBP")
    }

    @Test("the chart keeps its range when the screen is rebuilt for the same pair, as it is when the Duo folds")
    func samePairKeepsTheChartState() throws {
        let viewModel = try makeViewModel()
        viewModel.chart(base: "USD", target: "GBP").selectedTimeRange = .oneYear

        let rebuilt = viewModel.chart(base: "USD", target: "GBP")

        #expect(rebuilt.selectedTimeRange == .oneYear)
    }

    @Test("changing either currency in the converter moves the chart to the new pair")
    func pairChangeMovesTheChart() throws {
        let viewModel = try makeViewModel()
        _ = viewModel.chart(base: "USD", target: "GBP")

        let newTarget = viewModel.chart(base: "USD", target: "JPY")
        let newBase = viewModel.chart(base: "CHF", target: "JPY")

        #expect(newTarget.baseCurrency == "USD")
        #expect(newTarget.targetCurrency == "JPY")
        #expect(newBase.baseCurrency == "CHF")
        #expect(newBase.targetCurrency == "JPY")
    }

    private func makeViewModel() throws -> ConverterChartViewModel {
        let graph = try HistoryTestGraph()
        return ConverterChartViewModel(makeHistoryViewModel: graph.makeHistoryViewModel(for:))
    }
}
