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
                    await dependencyContainer.historyViewModel.initializeTrendData()
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
