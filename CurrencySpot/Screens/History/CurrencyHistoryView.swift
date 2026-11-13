import SwiftUI

struct CurrencyHistoryView: View {
    @Environment(\.scenePhase) private var scenePhase
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

    private var isShowingChart: Bool {
        !viewModel.showLoadingOverlay && viewModel.chartStatistics != nil
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            sections

            ScrollView { sections }
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
                let message: LocalizedStringResource = viewModel.isWaitingForConnection
                    ? .errorNoInternetTitle
                    : .historyChartFailed
                AccessibilityNotification.Announcement(String(localized: message)).post()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: viewModel.appMovedToBackground()
            case .active: viewModel.appBecameActive()
            default: break
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
            await viewModel.loadChart()
        }
        .task {
            await viewModel.presentChartOnboardingIfNeeded()
        }
        .environment(viewModel)
    }

    private var sections: some View {
        VStack(spacing: Spacing.section) {
            HeaderSection(isChartSelectionActive: $isChartSelectionActive)

            ChartSection(isChartSelectionActive: $isChartSelectionActive)

            StatisticsSection()

            if isShowingChart {
                ChartUpdateStatus()
            }

            Spacer()
        }
    }
}

#if DEBUG
#Preview {
    CurrencyHistoryView(viewModel: .preview())
}
#endif
