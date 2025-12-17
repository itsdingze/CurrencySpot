//
//  SettingsView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/19/25.
//

import SwiftUI

// MARK: - Supporting Types

private enum AlertType: Identifiable {
    case clearCachedData, resetPreferences

    var id: Self { self }

    func alert(onConfirm: @escaping (AlertType) -> Void) -> Alert {
        switch self {
        case .clearCachedData:
            Alert(
                title: Text("Clear Cached Data"),
                message: Text("This will remove all cached exchange rates and historical data. You'll need to fetch new data when you next use the app."),
                primaryButton: .destructive(Text("Clear")) { onConfirm(self) },
                secondaryButton: .cancel()
            )
        case .resetPreferences:
            Alert(
                title: Text("Reset Preferences"),
                message: Text("This will reset all settings to their default values. Your cached data will not be affected."),
                primaryButton: .destructive(Text("Reset")) { onConfirm(self) },
                secondaryButton: .cancel()
            )
        }
    }
}

struct SettingsView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel: CalculatorViewModel
    @Environment(SettingsViewModel.self) private var settingsViewModel: SettingsViewModel
    @Environment(AppState.self) private var appState: AppState

    @State private var alertType: AlertType?
    @State private var toastData: ToastData?

    private var bindableSettingsViewModel: Bindable<SettingsViewModel> {
        Bindable(settingsViewModel)
    }

    // MARK: - View Body

    var body: some View {
        Form {
            appearanceSection
            currencyPreferencesSection
            dataManagementSection
            aboutSection

//            #if DEBUG
//                Section(header: Text("Developer Options")) {
//                    NavigationLink("Debug Error Handling") {
//                        DebugErrorView(appState: _appState, calculatorViewModel: _calculatorViewModel)
//                    }
//                }
//            #endif
        }
        .alert(item: $alertType) { $0.alert(onConfirm: handleAlertConfirmation) }
        .overlay(toastOverlay)
    }

    // MARK: - UI Sections

    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            AccentColorPickerSheet()

            Picker(selection: bindableSettingsViewModel.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.rawValue)
                        .fontDesign(.rounded)
                        .tag(mode)
                }
            } label: {
                Label(title: {
                    Text("Color Scheme")
                }, icon: {
                    Image(systemName: "moon.circle.fill")
                        .symbolRenderingMode(.multicolor)
                })
            }
            .accessibilityLabel("Color scheme preference")
            .accessibilityHint("Changes the app's appearance between light, dark, or system mode")
            .accessibilityInputLabels(["Color scheme", "Appearance", "Theme"])
        }
    }

    private var currencyPreferencesSection: some View {
        Section(
            header: Text("Currency Preferences"),
            footer: Text("These settings determine the default values used when you open the app.")
        ) {
            currencyNavigationLink(
                title: "Default Base Currency",
                icon: "dollarsign.circle.fill",
                iconColors: (Color.white, Color.green),
                currentValue: settingsViewModel.defaultBaseCurrency,
                destination: CurrencyPickerView(
                    selectedCurrency: bindableSettingsViewModel.defaultBaseCurrency,
                    exchangeRates: calculatorViewModel.availableRates
                )
            )
            .accessibilityHint("Set the default source currency for conversions")

            currencyNavigationLink(
                title: "Default Target Currency",
                icon: "dollarsign.circle.fill",
                iconColors: (Color.white, Color.green),
                currentValue: settingsViewModel.defaultTargetCurrency,
                destination: CurrencyPickerView(
                    selectedCurrency: bindableSettingsViewModel.defaultTargetCurrency,
                    exchangeRates: calculatorViewModel.availableRates
                )
            )
            .accessibilityHint("Set the default target currency for conversions")

            NavigationLink(destination: FavoriteCurrenciesView()) {
                Label("Favorite Currencies", systemImage: "star.circle.fill")
                    .symbolRenderingMode(.multicolor)
            }
            .accessibilityLabel("Manage favorite currencies")
            .accessibilityHint("Customize which currencies appear in the quick selection")
            .accessibilityInputLabels(["Favorites", "Favorite currencies", "Currency favorites"])
        }
    }

    private var dataManagementSection: some View {
        Section {
            settingsActionButton(
                icon: "trash.circle.fill",
                title: "Clear Cached Data",
                action: { alertType = .clearCachedData }
            )
            .accessibilityLabel("Clear cached data")
            .accessibilityHint("Removes all cached exchange rates and historical data")
            .accessibilityInputLabels(["Clear cache", "Delete cached data"])

            settingsActionButton(
                icon: "arrow.triangle.2.circlepath.circle.fill",
                title: "Reset All Preferences",
                action: { alertType = .resetPreferences }
            )
            .accessibilityLabel("Reset all preferences")
            .accessibilityHint("Resets all settings to their default values")
            .accessibilityInputLabels(["Reset settings", "Restore defaults"])
        }
    }

    private var aboutSection: some View {
        Section(header: Text("About")) {
            LabeledContent {
                Text(Bundle.main.appVersionWithBuild)
                    .foregroundColor(.secondary)
            } label: {
                Label(title: {
                    Text("Version")
                }, icon: {
                    Image(systemName: "info.circle.fill")
                        .symbolRenderingMode(.multicolor)
                })
            }

            Link(destination: URL(string: "https://currencyspot.vercel.app")!) {
                HStack {
                    Label(title: {
                        Text("Privacy Policy")
                    }, icon: {
                        Image(systemName: "lock.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Color.blue)
                    })

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .tint(.primary)
            .accessibilityLabel("Privacy Policy")
            .accessibilityHint("Opens privacy policy in your web browser")
            .accessibilityInputLabels(["Privacy", "Privacy policy"])
        }
    }

    private var toastOverlay: some View {
        Group {
            if let toast = toastData {
                ToastView(message: toast.message, icon: toast.icon)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: toastData != nil)
    }

    // MARK: - Private Views

    @ViewBuilder
    private func currencyNavigationLink(
        title: String,
        icon: String,
        iconColors: (Color, Color),
        currentValue: String,
        destination: some View
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Label(title: {
                    Text(title)
                }, icon: {
                    Image(systemName: icon)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(iconColors.0, iconColors.1)
                })

                Spacer()

                Text(currentValue)
                    .foregroundStyle(.secondary)
                    .fontDesign(.rounded)
            }
        }
    }

    @ViewBuilder
    private func settingsActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: icon)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Helper Methods

    private func handleAlertConfirmation(for alertType: AlertType) {
        switch alertType {
        case .clearCachedData:
            Task {
                await settingsViewModel.clearCachedData()
                showToast(.cacheCleared)
            }
        case .resetPreferences:
            settingsViewModel.resetSettingsToDefault()
            showToast(.preferencesReset)
        }
    }

    private func showToast(_ type: ToastType) {
        toastData = ToastData(type: type)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toastData = nil
        }
    }
}

#Preview {
    let container = DependencyContainer.preview()

    NavigationStack {
        SettingsView()
    }
    .withDependencyContainer(container)
}
