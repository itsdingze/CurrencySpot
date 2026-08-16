import SwiftUI

@main
struct CurrencySpotApp: App {
    let dependencyContainer: DependencyContainer

    init() {
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
