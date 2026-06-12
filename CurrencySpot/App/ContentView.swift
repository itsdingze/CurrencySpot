//
//  ContentView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            Tab("Convert", systemImage: "arrow.left.arrow.right", value: AppTab.convert) {
                CalculatorView()
                    .toolbarBackground(.visible, for: .tabBar)
            }
            .accessibilityLabel("Currency Converter")
            .accessibilityHint("Convert between different currencies")
            .accessibilityInputLabels(["Convert", "Calculator", "Exchange"])

            if CameraScanAvailability.isSupported {
                Tab("Camera", systemImage: "camera.viewfinder", value: AppTab.camera) {
                    CameraView()
                        .toolbarBackground(.visible, for: .tabBar)
                        .toolbarColorScheme(.dark, for: .tabBar)
                }
                .accessibilityLabel("Camera Price Converter")
                .accessibilityHint("Point the camera at prices to see them converted")
                .accessibilityInputLabels(["Camera", "Scan", "Scanner"])
            }

            Tab("History", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.history) {
                CurrencyListView()
                    .toolbarBackground(.visible, for: .tabBar)
            }
            .accessibilityLabel("Exchange Rate History")
            .accessibilityHint("View historical exchange rate charts and trends")
            .accessibilityInputLabels(["History", "Charts", "Trends"])

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
                .toolbarBackground(.visible, for: .tabBar)
            }
            .accessibilityLabel("Settings and Preferences")
            .accessibilityHint("Configure app settings and default currencies")
            .accessibilityInputLabels(["Settings", "Preferences", "Configuration"])
        }
        .alert(
            "Error: \(appState.errorHandler.currentError?.title ?? "")",
            isPresented: errorAlertPresented,
            presenting: appState.errorHandler.currentError
        ) { _ in
            Button("OK", action: appState.errorHandler.dismiss)
        } message: { error in
            Text("Error details: \(error.message)")
        }
        .onAppear {
            settingsViewModel.presentOnboardingIfNeeded()
        }
        .sheet(isPresented: onboardingPresented) {
            CurrencySpotOnboarding()
                .onDisappear {
                    settingsViewModel.completeOnboarding()
                }
        }
    }

    // MARK: - Presentation Bindings

    /// `currentError` is the single source of truth; system dismissal of the
    /// alert routes through the handler's `dismiss()`.
    private var errorAlertPresented: Binding<Bool> {
        Binding(
            get: { appState.errorHandler.currentError != nil },
            set: { isActive in
                if !isActive {
                    appState.errorHandler.dismiss()
                }
            }
        )
    }

    private var onboardingPresented: Binding<Bool> {
        Bindable(settingsViewModel).destination.isPresenting(.onboarding)
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    @Previewable @State var appState = AppState.shared
    let container = DependencyContainer.preview()

    ContentView()
        .withDependencyContainer(container)
        .environment(appState)
}
#endif
