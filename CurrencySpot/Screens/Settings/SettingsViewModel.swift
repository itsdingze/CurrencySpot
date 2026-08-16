import SwiftUI

// MARK: - SettingsViewModel

@Observable
final class SettingsViewModel {
    // MARK: - Navigation State

    nonisolated enum Destination: Equatable {
        case alert(SettingsAlert)
        case accentColorPicker
        case addFavoriteCurrency
        case onboarding
    }

    nonisolated enum SettingsAlert: Identifiable {
        case refreshAllData
        case resetPreferences

        var id: Self { self }

        var title: String {
            switch self {
            case .refreshAllData: "Refresh All Data"
            case .resetPreferences: "Reset Preferences"
            }
        }

        var message: String {
            switch self {
            case .refreshAllData:
                "This will erase all locally stored exchange rates and historical data, then download fresh data from the network."
            case .resetPreferences:
                "This will reset all settings to their default values. Your stored data will not be affected."
            }
        }

        var confirmTitle: String {
            switch self {
            case .refreshAllData: "Refresh"
            case .resetPreferences: "Reset"
            }
        }
    }

    var destination: Destination?

    var pendingAlert: SettingsAlert? {
        if case let .alert(alert) = destination { return alert }
        return nil
    }

    private(set) var toast: ToastData?

    private var toastDismissTask: Task<Void, Never>?

    // MARK: - Private Properties

    private let preferences: PreferencesStore
    private let refreshAllDataUseCase: RefreshAllDataUseCase
    private let watchlist: WatchlistStore
    private let appState: AppState
    private let clock: ClockService
    private let logger: LoggerService

    // MARK: - Initialization

    init(
        refreshAllDataUseCase: RefreshAllDataUseCase,
        watchlist: WatchlistStore,
        preferences: PreferencesStore,
        appState: AppState = .shared,
        clock: ClockService = ContinuousClockService(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.refreshAllDataUseCase = refreshAllDataUseCase
        self.watchlist = watchlist
        self.preferences = preferences
        self.appState = appState
        self.clock = clock
        self.logger = logger
    }

    // MARK: - Presentation Intents

    func refreshAllDataTapped() {
        destination = .alert(.refreshAllData)
    }

    func resetPreferencesTapped() {
        destination = .alert(.resetPreferences)
    }

    func accentColorTapped() {
        destination = .accentColorPicker
    }

    func addFavoriteTapped() {
        destination = .addFavoriteCurrency
    }

    func dismissDestination() {
        destination = nil
    }

    func confirmAlert(_ alert: SettingsAlert) {
        switch alert {
        case .refreshAllData:
            guard appState.networkMonitor.isConnected else {
                appState.errorHandler.handle(AppError.noInternetConnection)
                return
            }
            Task {
                if await refreshAllData() {
                    showToast(.dataRefreshing)
                }
            }
        case .resetPreferences:
            resetSettingsToDefault()
            showToast(.preferencesReset)
        }
    }

    private func showToast(_ type: ToastType) {
        toast = ToastData(type: type)

        toastDismissTask?.cancel()
        toastDismissTask = Task { [clock] in
            try? await clock.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }

    // MARK: - Onboarding Intents

    func presentOnboardingIfNeeded() {
        guard !preferences.hasSeenOnboarding else { return }
        destination = .onboarding
    }

    func dismissOnboarding() {
        if destination == .onboarding {
            destination = nil
        }
    }

    func completeOnboarding() {
        preferences.hasSeenOnboarding = true
    }

    // MARK: - Public Settings Methods

    var accentColor: AccentColorOption {
        get { preferences.accentColor }
        set { preferences.accentColor = newValue }
    }

    var appearanceMode: AppearanceMode {
        get { preferences.appearanceMode }
        set { preferences.appearanceMode = newValue }
    }

    var defaultBaseCurrency: CurrencyCode {
        get { preferences.defaultBaseCurrency }
        set { preferences.defaultBaseCurrency = newValue }
    }

    var defaultTargetCurrency: CurrencyCode {
        get { preferences.defaultTargetCurrency }
        set { preferences.defaultTargetCurrency = newValue }
    }

    var favoriteCurrencies: [CurrencyCode] {
        preferences.favoriteCurrencies.elements
    }

    func addFavorite(_ code: CurrencyCode) {
        preferences.addFavorite(code)
    }

    func removeFavorites(atOffsets offsets: IndexSet) {
        for code in offsets.map({ preferences.favoriteCurrencies[$0] }) {
            preferences.removeFavorite(code)
        }
    }

    func moveFavorites(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        preferences.moveFavorites(from: offsets, to: destination)
    }

    func addableCurrencies(from rates: [ExchangeRate], matching searchText: String) -> [ExchangeRate] {
        CurrencySearch.results(
            in: rates,
            excluding: Set(preferences.favoriteCurrencies),
            matching: searchText
        )
    }

    func resetSettingsToDefault() {
        preferences.resetToDefaults()

        watchlist.reset(to: preferences.favoriteCurrencies.elements)
    }

    // MARK: - Data Management Methods

    @discardableResult
    func refreshAllData() async -> Bool {
        do {
            try await refreshAllDataUseCase.execute()
            logger.info("Data wipe complete; refresh started", category: .viewModel)
            return true
        } catch {
            logger.error("Failed to refresh data: \(error)", category: .viewModel)

            if let appError = AppError.from(error) {
                appState.errorHandler.handle(appError)
            }
            return false
        }
    }
}
