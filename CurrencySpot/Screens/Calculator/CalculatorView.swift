//
//  CalculatorView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/26/25.
//

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

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            VStack(spacing: .elementGap) {
                if calculatorViewModel.rateBanner != .hidden {
                    RateStatusBanner(
                        status: calculatorViewModel.rateBanner,
                        showsRetry: calculatorViewModel.canRetryRates,
                        refreshAction: calculatorViewModel.retryFetch
                    )
                }

                switch calculatorViewModel.loadState {
                case .idle, .loading(previous: nil):
                    // First load — nothing to show yet.
                    ProgressView("Loading exchange rates…")
                case .loaded, .loading(previous: .some):
                    // Saved rates stay on screen while a refresh runs; the banner reads
                    // "Updating…" rather than blanking to a spinner.
                    mainContentView()
                case .failed:
                    CalculatorErrorView()
                }
            }
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
                AccessibilityNotification.Announcement("Couldn't load exchange rates. Try again or use sample rates.").post()
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
            // The picker is also pushed from Settings, so the presentation
            // context owns the stack (a stack inside a pushed destination
            // invalidates value-based navigation registration).
            NavigationStack {
                CurrencyPickerView(
                    selectedCurrency: destination == .basePicker ? bindableViewModel.baseCurrency : bindableViewModel.targetCurrency,
                    exchangeRates: calculatorViewModel.availableRates
                )
            }
        }
    }

    private func mainContentView() -> some View {
        VStack(spacing: .elementGap) {
            CurrencyDisplayView()
                .accessibilityFocused($focusResult)
                .layoutPriority(1)

            RateInfoView()

            NumberPadView()
                .layoutPriority(2)
        }
        .safeAreaPadding()
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview("Loaded") {
    CalculatorView()
        .withDependencyContainer(DependencyContainer.preview())
}

#Preview("Loading") {
    CalculatorView()
        .environment(CalculatorViewModel.preview(.stalled))
        .withDependencyContainer(DependencyContainer.preview())
}

#Preview("Failed") {
    CalculatorView()
        .environment(CalculatorViewModel.preview(.failing))
        .withDependencyContainer(DependencyContainer.preview())
}
#endif
