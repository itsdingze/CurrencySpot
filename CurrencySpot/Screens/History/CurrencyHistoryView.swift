import SwiftUI

struct CurrencyHistoryView: View {
    @Environment(HistoryViewModel.self) private var viewModel: HistoryViewModel
    @State private var isChartSelectionActive: Bool = false

    private var chartIsLoaded: Bool {
        if case .loaded = viewModel.chartData { return true }
        return false
    }

    var body: some View {
        VStack(spacing: Spacing.section) {
            HeaderSection(
                isChartSelectionActive: $isChartSelectionActive
            )

            ChartSection(isChartSelectionActive: $isChartSelectionActive)

            StatisticsSection()

            Spacer()
        }
        .safeAreaPadding()
        .onChange(of: chartIsLoaded) { _, loaded in
            if loaded {
                let message = viewModel.displayedChartDataPoints.isEmpty
                    ? "No historical data available for this currency"
                    : "Exchange rate chart loaded"
                AccessibilityNotification.Announcement(message).post()
            }
        }
        .sheet(isPresented: Bindable(viewModel).destination.isPresenting(.chartOnboarding)) {
            ChartOnboardingView()
        }
        .task {
            await viewModel.presentChartOnboardingIfNeeded()
        }
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    CurrencyHistoryView()
        .withDependencyContainer(container)
}
#endif
