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
                if !appState.networkMonitor.isConnected, calculatorViewModel.lastUpdated != nil {
                    OfflineBanner(
                        refreshAction: calculatorViewModel.retryFetch,
                        isUsingMockData: calculatorViewModel.isUsingMockData,
                        retryState: calculatorViewModel.retryState
                    )
                }

                switch calculatorViewModel.loadState {
                case .idle, .loading:
                    ProgressView("Loading exchange rates...")
                case let .failed(error, _):
                    CalculatorErrorView(errorMessage: error.message)
                case .loaded:
                    mainContentView()
                }
            }
        }
        .task {
            await calculatorViewModel.checkIfShouldFetch()
        }
        .onChange(of: ratesAreLoaded) { _, loaded in
            if loaded {
                AccessibilityNotification.Announcement("Exchange rates loaded").post()
            }
        }
        .onChange(of: ratesDidFail) { _, failed in
            if failed {
                AccessibilityNotification.Announcement("Couldn't load exchange rates. Retry or use sample data.").post()
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
