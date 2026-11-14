import SwiftUI

struct CurrencyHistoryView: View {
    @State private var viewModel: CurrencyHistoryViewModel

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
        CurrencyHistoryContent(viewModel: viewModel)
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
                    let message: LocalizedStringResource = viewModel.isWaitingForConnection
                        ? .errorNoInternetTitle
                        : .historyChartFailed
                    AccessibilityNotification.Announcement(String(localized: message)).post()
                }
            }
            .sheet(isPresented: $viewModel.destination.isPresenting(.chartOnboarding)) {
                ChartOnboardingView()
                    .environment(viewModel)
                    .fitsFoldedScreen()
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
                await viewModel.presentChartOnboardingIfNeeded()
            }
    }
}

#if DEBUG
#Preview {
    CurrencyHistoryView(viewModel: .preview())
}
#endif
