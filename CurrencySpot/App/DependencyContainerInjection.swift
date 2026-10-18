import SwiftUI

extension View {
    func withDependencyContainer(_ container: DependencyContainer) -> some View {
        environment(container.appState)
            .environment(container.ratesStore)
            .environment(container.calculatorViewModel)
            .environment(container.currencyListViewModel)
            .environment(container.settingsViewModel)
            .environment(container.cameraViewModel)
    }
}
