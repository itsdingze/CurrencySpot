import SwiftUI

extension View {
    func withDependencyContainer(_ container: DependencyContainer) -> some View {
        environment(container)
            .environment(container.appState)
            .environment(container.ratesStore)
            .environment(container.calculatorViewModel)
            .environment(container.historyViewModel)
            .environment(container.settingsViewModel)
            .environment(container.cameraViewModel)
    }
}
