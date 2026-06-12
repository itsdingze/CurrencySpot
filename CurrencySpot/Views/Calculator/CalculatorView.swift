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

    private var bindableViewModel: Bindable<CalculatorViewModel> {
        Bindable(calculatorViewModel)
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            VStack(spacing: 12) {
                if !appState.networkMonitor.isConnected, calculatorViewModel.lastUpdated != nil {
                    OfflineBanner(
                        refreshAction: {
                            Task {
                                await calculatorViewModel.fetchExchangeRates()
                            }
                        },
                        isUsingMockData: calculatorViewModel.isUsingMockData,
                        retryState: calculatorViewModel.retryState
                    )
                }

                switch calculatorViewModel.loadState {
                case .idle, .loading:
                    ProgressView("Loading exchange rates...")
                        .accessibilityLabel("Loading exchange rates")
                        .accessibilityHint("Please wait while current exchange rates are being fetched")
                        .accessibilityAddTraits(.updatesFrequently)
                case let .failed(error, _):
                    CalculatorErrorView(errorMessage: error.message)
                        .accessibilityLabel("Error loading exchange rates")
                        .accessibilityValue("Error: \(error.message)")
                        .accessibilityHint("Exchange rates could not be loaded")
                case .loaded:
                    mainContentView()
                }
            }
        }
        .task {
            await calculatorViewModel.checkIfShouldFetch()
        }
        .onAppear {
            calculatorViewModel.consumePendingConversion()
        }
        .onChange(of: appState.pendingConversion) { _, newValue in
            if newValue != nil {
                calculatorViewModel.consumePendingConversion()
            }
        }
        .sheet(item: bindableViewModel.destination) { destination in
            CurrencyPickerView(
                selectedCurrency: destination == .basePicker ? bindableViewModel.baseCurrency : bindableViewModel.targetCurrency,
                exchangeRates: calculatorViewModel.availableRates
            )
        }
    }

    private func mainContentView() -> some View {
        VStack(spacing: 12) {
            CurrencyDisplayView()
                .layoutPriority(1)

            RateInfoView()

            NumberPadView()
                .layoutPriority(2)
        }
        .safeAreaPadding()
    }
}

#Preview {
    CalculatorView()
        .withDependencyContainer(DependencyContainer.preview())
}
