import SwiftUI

@main
struct CurrencySpotApp: App {
    private let dependencyContainer: DependencyContainer

    init() {
        dependencyContainer = DependencyContainer.bootstrap(appState: .shared)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .appAccent(dependencyContainer.settingsViewModel.accentColor.color)
                .preferredColorScheme(getPreferredColorScheme())
                .withDependencyContainer(dependencyContainer)
                .task {
                    dependencyContainer.currencyListViewModel.warmUp()
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
