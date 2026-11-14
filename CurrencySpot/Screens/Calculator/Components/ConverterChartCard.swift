import SwiftUI

struct ConverterChartCard: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel
    @Environment(ConverterChartViewModel.self) private var chartViewModel

    var body: some View {
        let chart = chartViewModel.chart(
            base: calculatorViewModel.baseCurrency,
            target: calculatorViewModel.targetCurrency
        )
        CurrencyHistoryContent(viewModel: chart)
            .id(ObjectIdentifier(chart))
            .background(Color.secondaryBackground, in: .rect(cornerRadius: Radius.container))
    }
}

#if DEBUG
#Preview {
    ConverterChartCard()
        .padding()
        .background(Color.background)
        .withDependencyContainer(.preview())
}
#endif
