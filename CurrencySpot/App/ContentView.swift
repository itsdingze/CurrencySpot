import SwiftUI

struct ContentView: View {
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            Tab(value: AppTab.convert) {
                CalculatorView()
                    .toolbarBackground(.visible, for: .tabBar)
            } label: {
                Label(.appTabConvert, systemImage: "arrow.left.arrow.right")
            }

            if CameraScanAvailability.isSupported {
                Tab(value: AppTab.camera) {
                    CameraView()
                        .toolbarBackground(.visible, for: .tabBar)
                        .toolbarColorScheme(.dark, for: .tabBar)
                } label: {
                    Label(.appTabCamera, systemImage: "camera.viewfinder")
                }
            }

            Tab(value: AppTab.history) {
                CurrencyListView()
                    .toolbarBackground(.visible, for: .tabBar)
            } label: {
                Label(.appTabHistory, systemImage: "chart.line.uptrend.xyaxis")
            }

            Tab(value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
                .toolbarBackground(.visible, for: .tabBar)
            } label: {
                Label(.appTabSettings, systemImage: "gearshape")
            }
        }
        .alert(
            errorAlertTitle,
            isPresented: Bindable(appState.errorHandler).isPresentingError,
            presenting: appState.errorHandler.currentError
        ) { _ in
            Button(.appErrorAlertDismiss, action: appState.errorHandler.dismiss)
        } message: { error in
            Text(error.message)
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

    // MARK: - Error Alert

    private var errorAlertTitle: Text {
        guard let error = appState.errorHandler.currentError else { return Text(verbatim: "") }
        return Text(error.title)
    }

    // MARK: - Presentation Bindings

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
