import SwiftUI

struct CalculatorView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @Environment(\.screenLayout) private var screenLayout

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

    private var failureAnnouncement: LocalizedStringResource {
        switch calculatorViewModel.failureRecovery {
        case .retry: .calculatorAnnouncementFailedRetry
        case .sampleRates: .calculatorAnnouncementFailedSampleRates
        }
    }

    var body: some View {
        NavigationStack {
            screen
                .toolbar { CalculatorToolbar(viewModel: calculatorViewModel, reduceMotion: reduceMotion) }
                .toolbarTitleDisplayMode(.inline)
        }
    }

    private var screen: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            VStack(spacing: Spacing.element) {
                switch calculatorViewModel.loadState {
                case .idle, .loading(previous: nil):
                    AccessibilitySizeScrollView {
                        ProgressView(.calculatorLoading)
                    }
                case .loaded, .loading(previous: .some):
                    mainContentView()
                case .failed:
                    AccessibilitySizeScrollView {
                        CalculatorErrorView()
                    }
                }
            }
            .safeAreaPadding([.horizontal, .bottom])
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
                AccessibilityNotification.Announcement(String(localized: .calculatorAnnouncementLoaded)).post()
            }
        }
        .onChange(of: ratesDidFail) { _, failed in
            if failed {
                AccessibilityNotification.Announcement(String(localized: failureAnnouncement)).post()
            }
        }
        .onAppear {
            calculatorViewModel.consumePendingConversion()
        }
        .onDisappear {
            calculatorViewModel.saveConversion()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                calculatorViewModel.saveConversion()
            }
        }
        .onChange(of: appState.pendingConversion) { _, newValue in
            if newValue != nil {
                calculatorViewModel.consumePendingConversion()
                focusResult = true
            }
        }
        .sheet(item: bindableViewModel.destination) { destination in
            switch destination {
            case .basePicker, .targetPicker:
                // A NavigationStack inside the picker breaks value-based navigation when Settings pushes it.
                NavigationStack {
                    CurrencyPickerView(
                        selectedCurrency: destination == .basePicker ? bindableViewModel.baseCurrency : bindableViewModel.targetCurrency,
                        exchangeRates: calculatorViewModel.availableRates,
                        favoriteCurrencies: calculatorViewModel.favoriteCurrencies
                    )
                }
            case .history:
                ConversionHistoryView()
            }
        }
    }

    @ViewBuilder
    private func mainContentView() -> some View {
        if screenLayout == .tent {
            AccessibilitySizeScrollView {
                HStack(spacing: Spacing.block) {
                    amountsWithRate
                    CalculatorKeypadView()
                }
            }
        } else if #available(iOS 27.1, *), screenLayout == .wide {
            CalculatorPage {
                AccessibilitySizeScrollView { converter }
            }
        } else {
            foldLayout
        }
    }

    private var foldLayout: some View {
        FoldAdaptiveLayout {
            AccessibilitySizeScrollView { converter }
        } top: {
            AccessibilitySizeScrollView { amountsWithRate }
        } bottom: {
            AccessibilitySizeScrollView { CalculatorKeypadView() }
        }
    }

    private var converter: some View {
        VStack(spacing: Spacing.element) {
            amounts
                .layoutPriority(1)

            RateInfoView()

            CalculatorKeypadView()
                .layoutPriority(2)
        }
    }

    private var amountsWithRate: some View {
        VStack(spacing: Spacing.element) {
            amounts
            RateInfoView()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var amounts: some View {
        CurrencyDisplayView()
            .accessibilityFocused($focusResult)
    }
}

@available(iOS 27.1, *)
private struct CalculatorPage<Content: View>: View {
    @Environment(\.toolbarVerticalEdge) private var barEdge

    @ViewBuilder let content: Content

    var body: some View {
        if barEdge == .leading {
            ArrangementView {
                content.padding(.trailing, Spacing.element)
            } secondary: {
                Color.clear
            }
            .arrangementViewStyle(.split.axes(.horizontal))
        } else {
            ArrangementView {
                Color.clear
            } secondary: {
                content.padding(.leading, Spacing.element)
            }
            .arrangementViewStyle(.split.axes(.horizontal))
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
