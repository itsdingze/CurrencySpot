import SwiftUI

struct CalculatorView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel
    @Environment(AppState.self) private var appState

    @AccessibilityFocusState private var focusResult: Bool

    private var bindableViewModel: Bindable<CalculatorViewModel> {
        Bindable(calculatorViewModel)
    }

    private var ratesAreLoaded: Bool {
        if case .loaded = calculatorViewModel.loadState { return true }
        return false
    }

    private var ratesDidFail: Bool {
        if case .failed = calculatorViewModel.loadState { return true }
        return false
    }

    private var failureAnnouncement: String {
        switch calculatorViewModel.failureRecovery {
        case .retry: "Couldn't load exchange rates. Try again."
        case .sampleRates: "Couldn't load exchange rates. Use sample rates."
        }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            VStack(spacing: Spacing.element) {
                if calculatorViewModel.rateBanner != .hidden {
                    RateStatusBanner(
                        status: calculatorViewModel.rateBanner,
                        showsRetry: calculatorViewModel.canRetryRates,
                        refreshAction: calculatorViewModel.retryFetch
                    )
                }

                switch calculatorViewModel.loadState {
                case .idle, .loading(previous: nil):
                    ProgressView("Loading exchange rates…")
                case .loaded, .loading(previous: .some):
                    mainContentView()
                case .failed:
                    CalculatorErrorView()
                }
            }
            .safeAreaPadding()
        }
        .task {
            await calculatorViewModel.checkIfShouldFetch()
        }
        .onChange(of: appState.networkMonitor.isConnected) { _, isConnected in
            if isConnected {
                Task { await calculatorViewModel.handleReconnect() }
            }
        }
        .onChange(of: ratesAreLoaded) { _, loaded in
            if loaded {
                AccessibilityNotification.Announcement("Exchange rates loaded").post()
            }
        }
        .onChange(of: ratesDidFail) { _, failed in
            if failed {
                AccessibilityNotification.Announcement(failureAnnouncement).post()
            }
        }
        .onAppear {
            calculatorViewModel.consumePendingConversion()
        }
        .onChange(of: appState.pendingConversion) { _, newValue in
            if newValue != nil {
                calculatorViewModel.consumePendingConversion()
                focusResult = true
            }
        }
        .sheet(item: bindableViewModel.destination) { destination in
            // A NavigationStack inside the picker breaks value-based navigation when Settings pushes it.
            NavigationStack {
                CurrencyPickerView(
                    selectedCurrency: destination == .basePicker ? bindableViewModel.baseCurrency : bindableViewModel.targetCurrency,
                    exchangeRates: calculatorViewModel.availableRates,
                    favoriteCurrencies: calculatorViewModel.favoriteCurrencies
                )
            }
        }
    }

    private func mainContentView() -> some View {
        VStack(spacing: Spacing.element) {
            CurrencyDisplayView()
                .accessibilityFocused($focusResult)
                .layoutPriority(1)

            RateInfoView()

            NumberPadView()
                .layoutPriority(2)
        }
    }
}

#if DEBUG
#Preview("Loaded") {
    CalculatorView()
        .withDependencyContainer(.preview())
}

#Preview("Loading") {
    CalculatorView()
        .withDependencyContainer(.preview(exchangeRateRepository: StubExchangeRateRepository(behavior: .stalled)))
}

#Preview("Failed") {
    CalculatorView()
        .withDependencyContainer(.preview(exchangeRateRepository: StubExchangeRateRepository(behavior: .failing)))
}
#endif
