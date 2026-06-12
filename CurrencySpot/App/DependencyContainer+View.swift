//
//  DependencyContainer+View.swift
//  CurrencySpot
//

import SwiftUI

extension View {
    /// Injects the DependencyContainer, AppState, and all ViewModels into the
    /// environment — one modifier covers app root and previews alike.
    func withDependencyContainer(_ container: DependencyContainer) -> some View {
        environment(container)
            .environment(container.appState)
            .environment(container.calculatorViewModel)
            .environment(container.historyViewModel)
            .environment(container.settingsViewModel)
            .environment(container.cameraViewModel)
    }
}
