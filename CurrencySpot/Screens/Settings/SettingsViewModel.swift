import Foundation
import Observation
import OSLog

// MARK: - SettingsViewModel

@Observable
final class SettingsViewModel {
    // MARK: - Navigation State

    nonisolated enum Destination: Equatable {
        case alert(SettingsAlert)
        case accentColorPicker
        case addFavoriteCurrency
        case onboarding
        case languageChangeNotice
    }

    nonisolated enum SettingsAlert {
        case refreshAllData
        case resetPreferences

        var title: LocalizedStringResource {
            switch self {
            case .refreshAllData: .settingsRefreshAllAlertTitle
            case .resetPreferences: .settingsResetPreferencesAlertTitle
            }
        }

        var message: LocalizedStringResource {
            switch self {
            case .refreshAllData: .settingsRefreshAllAlertMessage
            case .resetPreferences: .settingsResetPreferencesAlertMessage
            }
        }

        var confirmTitle: LocalizedStringResource {
            switch self {
            case .refreshAllData: .settingsRefreshAllConfirm
            case .resetPreferences: .settingsResetPreferencesConfirm
            }
        }
    }

    var destination: Destination?

    private(set) var toast: ToastData?

    private var toastDismissTask: Task<Void, Never>?

    private var refreshTask: Task<Void, Never>?

    private var selectedLanguage: AppLanguage

    // MARK: - Private Properties

    private let refreshAllDataUseCase: AllDataRefreshing
    private let resetPreferencesUseCase: ResetPreferencesUseCase
    private let manageFavoritesUseCase: ManageFavoritesUseCase
    private let preferences: PreferencesStore
    private let languageStore: AppLanguageStore
    private let appState: AppState
    private let clock: ClockService
    private let logger = Logger(category: .viewModel)

    // MARK: - Initialization

    init(
        refreshAllDataUseCase: AllDataRefreshing,
        resetPreferencesUseCase: ResetPreferencesUseCase,
        manageFavoritesUseCase: ManageFavoritesUseCase,
        preferences: PreferencesStore,
        languageStore: AppLanguageStore,
        appState: AppState,
        clock: ClockService
    ) {
        self.refreshAllDataUseCase = refreshAllDataUseCase
        self.resetPreferencesUseCase = resetPreferencesUseCase
        self.manageFavoritesUseCase = manageFavoritesUseCase
        self.preferences = preferences
        self.languageStore = languageStore
        selectedLanguage = languageStore.selectedLanguage
        self.appState = appState
        self.clock = clock
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
            guard refreshTask == nil else { return }
            refreshTask = Task {
                if await refreshAllData() {
                    showToast(.dataRefreshing)
                }
                refreshTask = nil
            }
        case .resetPreferences:
            resetPreferencesUseCase.execute()
            selectedLanguage = languageStore.selectedLanguage
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

    // MARK: - Preferences

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

    // MARK: - Language

    var availableLanguages: [AppLanguage] {
        languageStore.availableLanguages
    }

    var language: AppLanguage {
        get { selectedLanguage }
        set {
            guard newValue != selectedLanguage else { return }
            languageStore.selectedLanguage = newValue
            selectedLanguage = newValue
            destination = .languageChangeNotice
        }
    }

    // MARK: - Favorites

    var favoriteCurrencies: [CurrencyCode] {
        manageFavoritesUseCase.favorites
    }

    func addFavorite(_ code: CurrencyCode) {
        manageFavoritesUseCase.add(code)
    }

    func removeFavorites(atOffsets offsets: IndexSet) {
        manageFavoritesUseCase.remove(atOffsets: offsets)
    }

    func moveFavorites(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        manageFavoritesUseCase.move(fromOffsets: offsets, toOffset: destination)
    }

    func addableCurrencies(from rates: [ExchangeRate], matching searchText: String) -> [ExchangeRate] {
        manageFavoritesUseCase.addableCurrencies(from: rates, matching: searchText)
    }

    // MARK: - Data Management

    private func refreshAllData() async -> Bool {
        do {
            try await refreshAllDataUseCase.execute()
            appState.dataWasReset()
            logger.info("Data wipe complete; refresh started")
            return true
        } catch {
            logger.error("Failed to refresh data: \(error.localizedDescription, privacy: .public)")
            if let appError = AppError.from(error) {
                appState.errorHandler.handle(appError)
            }
            return false
        }
    }
}
