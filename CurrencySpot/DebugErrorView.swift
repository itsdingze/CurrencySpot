//
//  DebugErrorView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/24/25.
//

import SwiftUI

struct DebugErrorView: View {
    @Environment(AppState.self) var appState: AppState
    @Environment(CalculatorViewModel.self) var calculatorViewModel: CalculatorViewModel

    var body: some View {
        List {
            Section(header: Text("Simulate Errors")) {
                Button("Simulate Network Error") {
                    let error = AppError.networkError("Simulated network failure")
                    appState.errorHandler.handle(error)
                }

                Button("Simulate No Internet") {
                    let error = AppError.noInternetConnection
                    appState.errorHandler.handle(error)
                }

                Button("Simulate No Cache") {
                    let error = AppError.noCachedData
                    appState.errorHandler.handle(error)
                }

                Button("Simulate API Error") {
                    let error = AppError.apiError("API returned invalid response")
                    appState.errorHandler.handle(error)
                }

                Button("Clear All Data & Cache") {
                    UserDefaults.standard.removeObject(forKey: "ExchangeRatesKey")
                    UserDefaults.standard.removeObject(forKey: "HistoricalRatesKey")
                    UserDefaults.standard.removeObject(forKey: "LastFetchDateKey")
                    Task {
                        await calculatorViewModel.checkIfShouldFetch()
                    }
                }
            }
        }
    }
}
