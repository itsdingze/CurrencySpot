import SwiftUI

struct CurrencyHistoryView: View {
    @State private var viewModel: CurrencyHistoryViewModel
    @State private var isChartSelectionActive = false

    init(viewModel: CurrencyHistoryViewModel) {
        self.viewModel = viewModel
    }

    private var chartIsLoaded: Bool {
        if case .loaded = viewModel.chartData { return true }
        return false
    }

    private var chartDidFail: Bool {
        if case .failed = viewModel.chartData { return true }
        return false
    }

    var body: some View {
        AccessibilitySizeScrollView {
            VStack(spacing: Spacing.section) {
                HeaderSection(isChartSelectionActive: $isChartSelectionActive)

                ChartSection(isChartSelectionActive: $isChartSelectionActive)

                StatisticsSection()

                Spacer()
            }
        }
        .safeAreaPadding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BaseCurrencyButton(code: viewModel.baseCurrency, action: viewModel.baseCurrencyTapped)
            }
        }
        .onChange(of: chartIsLoaded) { _, loaded in
            if loaded {
                let message: LocalizedStringResource = viewModel.displayedChartDataPoints.isEmpty
                    ? .historyChartEmptyAnnouncement
                    : .historyChartLoadedAnnouncement
                AccessibilityNotification.Announcement(String(localized: message)).post()
            }
        }
        .onChange(of: chartDidFail) { _, failed in
            if failed {
                AccessibilityNotification.Announcement(String(localized: .historyChartFailed)).post()
            }
        }
        .sheet(isPresented: $viewModel.destination.isPresenting(.chartOnboarding)) {
            ChartOnboardingView()
                .environment(viewModel)
        }
        .sheet(isPresented: $viewModel.destination.isPresenting(.basePicker)) {
            BasePickerSheet(
                selection: viewModel.baseCurrency,
                favorites: viewModel.basePickerFavorites,
                exchangeRates: viewModel.basePickerRates,
                onSelect: { viewModel.selectBase($0) }
            )
        }
        .task {
            await viewModel.loadChart()
        }
        .task {
            await viewModel.presentChartOnboardingIfNeeded()
        }
        .environment(viewModel)
    }
}

#if DEBUG
#Preview {
    CurrencyHistoryView(viewModel: .preview())
}
#endif
