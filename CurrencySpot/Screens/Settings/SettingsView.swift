import SwiftUI

struct SettingsView: View {
    @Environment(ExchangeRatesStore.self) private var ratesStore: ExchangeRatesStore
    @Environment(SettingsViewModel.self) private var settingsViewModel: SettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        .navigationTitle(.settingsTitle)
        .navigationDestination(for: SettingsRoute.self) { route in
            destinationView(for: route)
        }
        .navigationDestination(for: Acknowledgement.self) { acknowledgement in
            LicenseDetailView(acknowledgement: acknowledgement)
        }
        .confirmationAlert(
            .refreshAllData,
            isPresented: bindableViewModel.destination.isPresenting(.alert(.refreshAllData)),
            onConfirm: { settingsViewModel.confirmAlert(.refreshAllData) }
        )
        .confirmationAlert(
            .resetPreferences,
            isPresented: bindableViewModel.destination.isPresenting(.alert(.resetPreferences)),
            onConfirm: { settingsViewModel.confirmAlert(.resetPreferences) }
        )
        .overlay { toastOverlay }
        .onChange(of: settingsViewModel.toast?.id) {
            if let toast = settingsViewModel.toast {
                AccessibilityNotification.Announcement(String(localized: toast.message)).post()
            }
        }
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
        Section(header: Text(.settingsAppearanceHeader)) {
            AccentColorPickerSheet()

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading) {
                    colorSchemeLabel
                        .accessibilityHidden(true)

                    colorSchemePicker
                        .labelsHidden()
                }
            } else {
                colorSchemePicker
            }
        }
    }

    private var colorSchemePicker: some View {
        Picker(selection: bindableViewModel.appearanceMode) {
            ForEach(AppearanceMode.allCases) { mode in
                Text(mode.displayName)
                    .fontDesign(.rounded)
                    .tag(mode)
            }
        } label: {
            colorSchemeLabel
        }
    }

    private var colorSchemeLabel: some View {
        Label(title: {
            Text(.settingsAppearanceColorScheme)
        }, icon: {
            Image(systemName: "moon.circle.fill")
                .symbolRenderingMode(.multicolor)
        })
    }

    private var currencyPreferencesSection: some View {
        Section(
            header: Text(.settingsCurrenciesHeader),
            footer: Text(.settingsCurrenciesFooter)
        ) {
            currencyNavigationLink(
                title: .settingsCurrenciesDefaultBase,
                icon: "dollarsign.circle.fill",
                iconColors: (Color.white, Color.green),
                currentValue: settingsViewModel.defaultBaseCurrency,
                route: .defaultBaseCurrency
            )

            currencyNavigationLink(
                title: .settingsCurrenciesDefaultTarget,
                icon: "dollarsign.circle.fill",
                iconColors: (Color.white, Color.green),
                currentValue: settingsViewModel.defaultTargetCurrency,
                route: .defaultTargetCurrency
            )

            NavigationLink(value: SettingsRoute.favoriteCurrencies) {
                Label(.settingsCurrenciesFavorites, systemImage: "star.circle.fill")
                    .symbolRenderingMode(.multicolor)
            }
        }
    }

    private var dataManagementSection: some View {
        Section {
            settingsActionButton(
                icon: "arrow.clockwise.circle.fill",
                title: .settingsDataRefreshAll,
                action: settingsViewModel.refreshAllDataTapped
            )
            .accessibilityHint(.settingsDataRefreshAllHint)

            settingsActionButton(
                icon: "arrow.triangle.2.circlepath.circle.fill",
                title: .settingsDataResetPreferences,
                action: settingsViewModel.resetPreferencesTapped
            )
            .accessibilityHint(.settingsDataResetPreferencesHint)
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink(value: SettingsRoute.about) {
                Label(title: {
                    Text(.settingsAboutRow)
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
                    .transition(reduceMotion ? AnyTransition.opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.appSelect, value: settingsViewModel.toast != nil)
    }

    // MARK: - Private Views

    @ViewBuilder
    private func currencyNavigationLink(
        title: LocalizedStringResource,
        icon: String,
        iconColors: (Color, Color),
        currentValue: CurrencyCode,
        route: SettingsRoute
    ) -> some View {
        NavigationLink(value: route) {
            AdaptiveStack {
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
    private func settingsActionButton(icon: String, title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Confirmation Alert

private extension View {
    func confirmationAlert(
        _ alert: SettingsViewModel.SettingsAlert,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        self.alert(alert.title, isPresented: isPresented) {
            Button(alert.confirmTitle, role: .destructive, action: onConfirm)
            Button(.settingsAlertCancel, role: .cancel) {}
        } message: {
            Text(alert.message)
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
