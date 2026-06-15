//
//  SettingsView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/19/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel: CalculatorViewModel
    @Environment(SettingsViewModel.self) private var settingsViewModel: SettingsViewModel
    @Environment(AppState.self) private var appState: AppState

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
        }
        .navigationDestination(for: SettingsRoute.self) { route in
            destinationView(for: route)
        }
        .navigationDestination(for: Acknowledgement.self) { acknowledgement in
            LicenseDetailView(acknowledgement: acknowledgement)
        }
        .alert(
            settingsViewModel.pendingAlert?.title ?? "",
            isPresented: isAlertPresented,
            presenting: settingsViewModel.pendingAlert
        ) { alert in
            Button(alert.confirmTitle, role: .destructive) {
                settingsViewModel.confirmAlert(alert)
            }
            Button("Cancel", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
        .overlay { toastOverlay }
    }

    /// Bool projection of the alert destination for the modern alert API;
    /// system dismissal writes `nil` back to the ViewModel.
    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { settingsViewModel.pendingAlert != nil },
            set: { isActive in
                if !isActive, settingsViewModel.pendingAlert != nil {
                    settingsViewModel.destination = nil
                }
            }
        )
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destinationView(for route: SettingsRoute) -> some View {
        switch route {
        case .defaultBaseCurrency:
            CurrencyPickerView(
                selectedCurrency: bindableSettingsViewModel.defaultBaseCurrency,
                exchangeRates: calculatorViewModel.availableRates
            )
        case .defaultTargetCurrency:
            CurrencyPickerView(
                selectedCurrency: bindableSettingsViewModel.defaultTargetCurrency,
                exchangeRates: calculatorViewModel.availableRates
            )
        case .favoriteCurrencies:
            FavoriteCurrenciesView()
        case .acknowledgements:
            AcknowledgementsView()
        }
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
                route: .defaultBaseCurrency
            )
            .accessibilityHint("Set the default source currency for conversions")

            currencyNavigationLink(
                title: "Default Target Currency",
                icon: "dollarsign.circle.fill",
                iconColors: (Color.white, Color.green),
                currentValue: settingsViewModel.defaultTargetCurrency,
                route: .defaultTargetCurrency
            )
            .accessibilityHint("Set the default target currency for conversions")

            NavigationLink(value: SettingsRoute.favoriteCurrencies) {
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
                icon: "arrow.clockwise.circle.fill",
                title: "Refresh All Data",
                action: settingsViewModel.refreshAllDataTapped
            )
            .accessibilityLabel("Refresh all data")
            .accessibilityHint("Erases all stored exchange rates and historical data, then downloads fresh data")
            .accessibilityInputLabels(["Refresh data", "Refresh all data"])

            settingsActionButton(
                icon: "arrow.triangle.2.circlepath.circle.fill",
                title: "Reset All Preferences",
                action: settingsViewModel.resetPreferencesTapped
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
                    .foregroundStyle(.secondary)
            } label: {
                Label(title: {
                    Text("Version")
                }, icon: {
                    Image(systemName: "info.circle.fill")
                        .symbolRenderingMode(.multicolor)
                })
            }

            if let privacyPolicyURL = URL(string: "https://currencyspot.vercel.app/privacy") {
                Link(destination: privacyPolicyURL) {
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
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .tint(.primary)
                .accessibilityLabel("Privacy Policy")
                .accessibilityHint("Opens privacy policy in your web browser")
                .accessibilityInputLabels(["Privacy", "Privacy policy"])
            }

            NavigationLink(value: SettingsRoute.acknowledgements) {
                Label(title: {
                    Text("Acknowledgements")
                }, icon: {
                    Image(systemName: "document.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.blue)
                })
            }
            .accessibilityLabel("Acknowledgements")
            .accessibilityHint("Shows open-source licenses for bundled software")
            .accessibilityInputLabels(["Acknowledgements", "Licenses", "Open source"])
        }
    }

    private var toastOverlay: some View {
        Group {
            if let toast = settingsViewModel.toast {
                ToastView(message: toast.message, icon: toast.icon)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.appSelect, value: settingsViewModel.toast != nil)
    }

    // MARK: - Private Views

    @ViewBuilder
    private func currencyNavigationLink(
        title: String,
        icon: String,
        iconColors: (Color, Color),
        currentValue: String,
        route: SettingsRoute
    ) -> some View {
        NavigationLink(value: route) {
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
                .foregroundStyle(Color.failure)
        }
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    NavigationStack {
        SettingsView()
    }
    .withDependencyContainer(container)
}
#endif
