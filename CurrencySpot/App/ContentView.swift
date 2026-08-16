import SwiftUI

struct ContentView: View {
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

            if CameraScanAvailability.isSupported {
                Tab("Camera", systemImage: "camera.viewfinder", value: AppTab.camera) {
                    CameraView()
                        .toolbarBackground(.visible, for: .tabBar)
                        .toolbarColorScheme(.dark, for: .tabBar)
                }
                .accessibilityLabel("Camera Price Converter")
            }

            Tab("History", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.history) {
                CurrencyListView()
                    .toolbarBackground(.visible, for: .tabBar)
            }
            .accessibilityLabel("Exchange Rate History")

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
                .toolbarBackground(.visible, for: .tabBar)
            }
            .accessibilityLabel("Settings and Preferences")
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
            AppOnboardingView()
                .onDisappear {
                    settingsViewModel.completeOnboarding()
                }
        }
    }

    // MARK: - Presentation Bindings

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

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    ContentView()
        .withDependencyContainer(container)
}
#endif
