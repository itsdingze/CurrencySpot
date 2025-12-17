//
//  CurrencySpotApp.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/26/25.
//

import SwiftData
import SwiftUI

@main
struct CurrencySpotApp: App {
    @State private var appState = AppState.shared
    let dependencyContainer: DependencyContainer

    init() {
        var inMemoryContainer: ModelContainer? = nil

        #if DEBUG
            if CommandLine.arguments.contains("enable-testing") {
                // Create in-memory container for testing
                do {
                    let configuration = ModelConfiguration(
                        for: ExchangeRateData.self,
                        HistoricalRateData.self,
                        TrendData.self,
                        isStoredInMemoryOnly: true
                    )
                    inMemoryContainer = try ModelContainer(
                        for: ExchangeRateData.self,
                        HistoricalRateData.self,
                        TrendData.self,
                        configurations: configuration
                    )
                } catch {
                    AppLogger.fault("Failed to create test container: \(error)", category: .app)
                    // Continue with default container
                }
            }
        #endif

        // Initialize DependencyContainer with optional test container
        do {
            dependencyContainer = try DependencyContainer(modelContainer: inMemoryContainer)
        } catch {
            // Log the error for debugging
            AppLogger.fault("Failed to initialize DependencyContainer: \(error)", category: .app)

            // Try to create in-memory fallback container
            do {
                let fallbackConfiguration = ModelConfiguration(
                    for: ExchangeRateData.self,
                    HistoricalRateData.self,
                    TrendData.self,
                    isStoredInMemoryOnly: true
                )
                let fallbackContainer = try ModelContainer(
                    for: ExchangeRateData.self,
                    HistoricalRateData.self,
                    TrendData.self,
                    configurations: fallbackConfiguration
                )

                dependencyContainer = try DependencyContainer(modelContainer: fallbackContainer)

                // Notify user about fallback mode
                DispatchQueue.main.async {
                    let fallbackError = AppError.initializationFailed("Persistent storage failed")
                    AppState.shared.errorHandler.handle(fallbackError)
                }

                AppLogger.info("Fallback to in-memory storage successful", category: .app)
            } catch {
                // If even in-memory fails, create minimal container with mock service
                AppLogger.fault("Critical error: Failed to initialize in-memory container: \(error)", category: .app)

                // Create a minimal container with mock service as last resort
                let mockService = MockExchangeRateService()
                dependencyContainer = DependencyContainer(mockService: mockService)

                // Notify user about critical error
                DispatchQueue.main.async {
                    let criticalError = AppError.initializationFailed("App initialization failed. Running in limited mode.")
                    AppState.shared.errorHandler.handle(criticalError)
                }

                AppLogger.warning("Running in limited mode with mock data", category: .app)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .accentColor(dependencyContainer.settingsViewModel.accentColor.color)
                .preferredColorScheme(getPreferredColorScheme())
                .withDependencyContainer(dependencyContainer)
                .environment(appState)
                .task {
                    await dependencyContainer.historyViewModel.initializeTrendData()
                }
        }
        .modelContainer(dependencyContainer.modelContainer)
    }

    private func getPreferredColorScheme() -> ColorScheme? {
        switch dependencyContainer.settingsViewModel.appearanceMode {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}
