//
//  CurrencySpotApp.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/26/25.
//

import SwiftUI

@main
struct CurrencySpotApp: App {
    let dependencyContainer: DependencyContainer

    init() {
        // The storage fallback ladder (persistent → in-memory → empty schema)
        // lives in the container's bootstrap factory.
        dependencyContainer = DependencyContainer.bootstrap(appState: .shared)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .accentColor(dependencyContainer.settingsViewModel.accentColor.color)
                .preferredColorScheme(getPreferredColorScheme())
                .withDependencyContainer(dependencyContainer)
                .task {
                    // Tiered warm-up: the tiny 7-day trend seed first so sparklines
                    // appear fast, then the 1-year window that makes every chart
                    // open, range switch (≤1Y), and currency switch render locally.
                    await dependencyContainer.historyViewModel.initializeTrendData()
                    await dependencyContainer.historyViewModel.prefetchHistoricalWindow()
                }
        }
    }

    private func getPreferredColorScheme() -> ColorScheme? {
        switch dependencyContainer.settingsViewModel.appearanceMode {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}
