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
    @State private var showOnBoarding = false

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabView
            } else {
                legacyTabView
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .alert(isPresented: Bindable(appState.errorHandler).showingError) {
            errorAlert
        }
        .onAppear {
            if !settingsViewModel.hasSeenOnboarding {
                showOnBoarding = true
            }
        }
        .sheet(isPresented: $showOnBoarding) {
            CurrencySpotOnboarding(showOnBoarding: $showOnBoarding)
                .onDisappear {
                    settingsViewModel.hasSeenOnboarding = true
                }
        }
    }

    // MARK: - Private Views

    @ViewBuilder @available(iOS 18.0, *)
    private var modernTabView: some View {
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
                CurrencyList()
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
    }

    @ViewBuilder
    private var legacyTabView: some View {
        @Bindable var appState = appState
        VStack {
            TabView(selection: $appState.selectedTab) {
                CalculatorView()
                    .tabItem {
                        Label("Convert", systemImage: "arrow.left.arrow.right")
                    }
                    .tag(AppTab.convert)
                    .toolbar(.hidden, for: .tabBar)
                    .accessibilityLabel("Currency Converter")
                    .accessibilityHint("Convert between different currencies")
                    .accessibilityInputLabels(["Convert", "Calculator", "Exchange"])

                NavigationStack {
                    CurrencyList()
                }
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.history)
                .toolbar(.hidden, for: .tabBar)
                .accessibilityLabel("Exchange Rate History")
                .accessibilityHint("View historical exchange rate charts and trends")
                .accessibilityInputLabels(["History", "Charts", "Trends"])

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
                    .toolbar(.hidden, for: .tabBar)
                    .accessibilityLabel("Settings and Preferences")
                    .accessibilityHint("Configure app settings and default currencies")
                    .accessibilityInputLabels(["Settings", "Preferences", "Configuration"])
            }
            CustomTabBar(selectedTab: $appState.selectedTab)
        }
    }

    private var errorAlert: Alert {
        if let error = appState.errorHandler.currentError {
            Alert(
                title: Text("Error: \(error.title)"),
                message: Text("Error details: \(error.message)"),
                dismissButton: .default(Text("OK")) {
                    appState.errorHandler.dismiss()
                }
            )
        } else {
            Alert(
                title: Text("Unknown error occurred"),
                message: Text("Error details: An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState.shared
    let container = DependencyContainer.preview()

    ContentView()
        .withDependencyContainer(container)
        .environment(appState)
}
