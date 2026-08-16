import SwiftUI

struct SettingsView: View {
    @Environment(ExchangeRatesStore.self) private var ratesStore: ExchangeRatesStore
    @Environment(SettingsViewModel.self) private var settingsViewModel: SettingsViewModel

    private var bindableViewModel: Bindable<SettingsViewModel> {
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
        .onChange(of: settingsViewModel.toast?.id) { _, newID in
            if newID != nil {
                AccessibilityNotification.Announcement(settingsViewModel.toast?.message ?? "").post()
            }
        }
    }

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
                selectedCurrency: bindableViewModel.defaultBaseCurrency,
                exchangeRates: ratesStore.rates,
                favoriteCurrencies: settingsViewModel.favoriteCurrencies
            )
        case .defaultTargetCurrency:
            CurrencyPickerView(
                selectedCurrency: bindableViewModel.defaultTargetCurrency,
                exchangeRates: ratesStore.rates,
                favoriteCurrencies: settingsViewModel.favoriteCurrencies
            )
        case .favoriteCurrencies:
            FavoriteCurrenciesView()
        case .about:
            AboutView()
        case .acknowledgements:
            AcknowledgementsView()
        }
    }

    // MARK: - UI Sections

    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            AccentColorPickerSheet()

            Picker(selection: bindableViewModel.appearanceMode) {
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

            currencyNavigationLink(
                title: "Default Target Currency",
                icon: "dollarsign.circle.fill",
                iconColors: (Color.white, Color.green),
                currentValue: settingsViewModel.defaultTargetCurrency,
                route: .defaultTargetCurrency
            )

            NavigationLink(value: SettingsRoute.favoriteCurrencies) {
                Label("Favorite Currencies", systemImage: "star.circle.fill")
                    .symbolRenderingMode(.multicolor)
            }
        }
    }

    private var dataManagementSection: some View {
        Section {
            settingsActionButton(
                icon: "arrow.clockwise.circle.fill",
                title: "Refresh All Data",
                action: settingsViewModel.refreshAllDataTapped
            )
            .accessibilityHint("Erases all stored exchange rates and historical data, then downloads fresh data")

            settingsActionButton(
                icon: "arrow.triangle.2.circlepath.circle.fill",
                title: "Reset All Preferences",
                action: settingsViewModel.resetPreferencesTapped
            )
            .accessibilityHint("Resets all settings to their default values")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink(value: SettingsRoute.about) {
                Label(title: {
                    Text("About")
                }, icon: {
                    Image(systemName: "info.circle.fill")
                        .symbolRenderingMode(.multicolor)
                })
            }
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
        currentValue: CurrencyCode,
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

                Text(currentValue.rawValue)
                    .foregroundStyle(.secondary)
                    .fontDesign(.rounded)
            }
        }
    }

    @ViewBuilder
    private func settingsActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: icon)
        }
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    NavigationStack {
        SettingsView()
    }
    .withDependencyContainer(container)
}
#endif
