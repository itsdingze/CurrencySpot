//
//  CalculatorView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/26/25.
//

import SwiftUI

struct CalculatorView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel
    @Environment(AppState.self) var appState

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

                if calculatorViewModel.isLoading {
                    ProgressView("Loading exchange rates...")
                        .accessibilityLabel("Loading exchange rates")
                        .accessibilityHint("Please wait while current exchange rates are being fetched")
                        .accessibilityAddTraits(.updatesFrequently)
                } else if let error = calculatorViewModel.errorMessage {
                    CalculatorErrorView(errorMessage: error)
                        .accessibilityLabel("Error loading exchange rates")
                        .accessibilityValue("Error: \(error)")
                        .accessibilityHint("Exchange rates could not be loaded")
                } else {
                    mainContentView()
                }
            }
        }
        .task {
            await calculatorViewModel.checkIfShouldFetch()
        }
        .sheet(isPresented: bindableViewModel.showCurrencyPicker) {
            CurrencyPickerView(
                selectedCurrency: calculatorViewModel.isSelectingFromCurrency ? bindableViewModel.baseCurrency : bindableViewModel.targetCurrency,
                exchangeRates: calculatorViewModel.availableRates
            )
        }
    }

    func mainContentView() -> some View {
        VStack(spacing: 12) {
            CurrencyDisplayView()
                .layoutPriority(1)

            RateInfoView()

            NumberPadView(inputValue: bindableViewModel.inputAmountString)
                .layoutPriority(2)
        }
        .safeAreaPadding()
    }
}

#Preview {
    @Previewable @State var appState = AppState.shared
    let container = DependencyContainer.preview()

    CalculatorView()
        .withDependencyContainer(container)
        .environment(appState)
}
