import AppIntents
import SwiftUI
import TipKit

@main
struct CurrencySpotApp: App {
    private let dependencyContainer: DependencyContainer

    init() {
        let dependencyContainer = DependencyContainer.bootstrap(appState: .shared)
        let convertCurrency = dependencyContainer.convertCurrencyUseCase
        AppDependencyManager.shared.add(dependency: convertCurrency)
        self.dependencyContainer = dependencyContainer
        try? Tips.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .appAccent(dependencyContainer.settingsViewModel.accentColor.color)
                .preferredColorScheme(getPreferredColorScheme())
                .withDependencyContainer(dependencyContainer)
                .task {
                    dependencyContainer.currencyListViewModel.warmUp()
                    await dependencyContainer.calculatorViewModel.checkIfShouldFetch()
                }
                .onOpenURL { url in
                    guard let link = HistoryLink(url: url) else { return }
                    dependencyContainer.currencyListViewModel.open(link)
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
