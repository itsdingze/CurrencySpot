//
//  SettingsViewModel.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/19/25.
//

import IdentifiedCollections
import SwiftUI

// MARK: - Supporting Types

/// Color theme options for the app
enum AccentColorOption: String, CaseIterable, Identifiable {
    case pink = "Pink"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case mint = "Mint"
    case cyan = "Cyan"
    case blue = "Blue"
    case indigo = "Indigo"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pink: .pink
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        }
    }
}

/// Appearance mode options
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

// MARK: - SettingsViewModel

@Observable
final class SettingsViewModel {
    // MARK: - Navigation State

    /// Mutually exclusive presentations driven by Settings (and the app's
    /// first-launch onboarding, which this ViewModel owns via `hasSeenOnboarding`).
    nonisolated enum Destination: Equatable {
        case alert(SettingsAlert)
        case accentColorPicker
        case onboarding
    }

    /// Destructive-action confirmations in Settings.
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

    /// The alert payload when `destination` is an alert (modern alert API shape).
    var pendingAlert: SettingsAlert? {
        if case let .alert(alert) = destination { return alert }
        return nil
    }

    /// Transient confirmation toast, auto-dismissed after 2 seconds.
    private(set) var toast: ToastData?

    private var toastDismissTask: Task<Void, Never>?

    // MARK: - Appearance Properties

    var accentColor: AccentColorOption {
        didSet {
            if oldValue != accentColor {
                saveSettings()
            }
        }
    }

    var appearanceMode: AppearanceMode {
        didSet {
            if oldValue != appearanceMode {
                saveSettings()
            }
        }
    }

    // MARK: - Currency Properties

    var defaultBaseCurrency: String {
        didSet {
            if oldValue != defaultBaseCurrency {
                saveSettings()
            }
        }
    }

    var defaultTargetCurrency: String {
        didSet {
            if oldValue != defaultTargetCurrency {
                saveSettings()
            }
        }
    }

    /// Keyed by the codes themselves so mutation is ID-based; the list is also
    /// reordered positionally (drag handles), which IdentifiedArray supports.
    private(set) var favoriteCurrencies: IdentifiedArray<String, String> {
        didSet {
            if oldValue != favoriteCurrencies {
                saveSettings()
            }
        }
    }

    // MARK: - Onboarding Properties

    var hasSeenOnboarding: Bool {
        didSet {
            if oldValue != hasSeenOnboarding {
                saveSettings()
            }
        }
    }

    var hasSeenChartOnboarding: Bool {
        didSet {
            if oldValue != hasSeenChartOnboarding {
                saveSettings()
            }
        }
    }

    // MARK: - Private Properties

    private let userDefaults: UserDefaults
    private let refreshAllDataUseCase: RefreshAllDataUseCase
    private let appState: AppState
    private let clock: ClockService
    private let logger: LoggerService

    // MARK: - Constants

    /// Default values for all settings
    private enum DefaultValues {
        static let accentColor: AccentColorOption = .cyan
        static let appearanceMode: AppearanceMode = .system
        static let baseCurrency = "USD"
        static let targetCurrency = "EUR"
        static let favoriteCurrencies = ["USD", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD"]
        static let hasSeenOnboarding = false
        static let hasSeenChartOnboarding = false
    }

    // MARK: - Initialization

    /// `userDefaults` defaults to `.standard`; tests inject an isolated suite.
    init(
        refreshAllDataUseCase: RefreshAllDataUseCase,
        appState: AppState = .shared,
        userDefaults: UserDefaults = .standard,
        clock: ClockService = ContinuousClockService(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.refreshAllDataUseCase = refreshAllDataUseCase
        self.appState = appState
        self.userDefaults = userDefaults
        self.clock = clock
        self.logger = logger

        accentColor = userDefaults.string(forKey: UserDefaultsKeys.accentColor)
            .flatMap { AccentColorOption(rawValue: $0) } ?? DefaultValues.accentColor

        appearanceMode = userDefaults.string(forKey: UserDefaultsKeys.appearanceMode)
            .flatMap { AppearanceMode(rawValue: $0) } ?? DefaultValues.appearanceMode

        defaultBaseCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultBaseCurrency) ?? DefaultValues.baseCurrency
        defaultTargetCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultTargetCurrency) ?? DefaultValues.targetCurrency
        favoriteCurrencies = Self.identifiedCurrencies(
            userDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies) ?? DefaultValues.favoriteCurrencies
        )
        hasSeenOnboarding = userDefaults.bool(forKey: UserDefaultsKeys.hasSeenOnboarding)
        hasSeenChartOnboarding = userDefaults.bool(forKey: UserDefaultsKeys.hasSeenChartOnboarding)
    }

    /// Builds the favorites collection dropping duplicates (old persisted data
    /// may contain them; `init(uniqueElements:)` would trap instead).
    private static func identifiedCurrencies(_ codes: [String]) -> IdentifiedArray<String, String> {
        var array = IdentifiedArray<String, String>(id: \.self)
        for code in codes {
            array.append(code)
        }
        return array
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

    /// Confirms the presented destructive alert and shows the matching toast.
    func confirmAlert(_ alert: SettingsAlert) {
        switch alert {
        case .refreshAllData:
            // Refresh promises a re-download; offline it would only destroy data
            // and silently swap in mock rates. Refuse instead of wiping.
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
            try? await clock.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }

    // MARK: - Onboarding Intents

    /// First-launch onboarding, presented from the app root.
    func presentOnboardingIfNeeded() {
        guard !hasSeenOnboarding else { return }
        destination = .onboarding
    }

    func dismissOnboarding() {
        if destination == .onboarding {
            destination = nil
        }
    }

    /// Marks onboarding as seen once its sheet leaves the screen.
    func completeOnboarding() {
        hasSeenOnboarding = true
    }

    // MARK: - Public Settings Methods

    /// Save all settings to UserDefaults
    func saveSettings() {
        userDefaults.set(accentColor.rawValue, forKey: UserDefaultsKeys.accentColor)
        userDefaults.set(appearanceMode.rawValue, forKey: UserDefaultsKeys.appearanceMode)
        userDefaults.set(defaultBaseCurrency, forKey: UserDefaultsKeys.defaultBaseCurrency)
        userDefaults.set(defaultTargetCurrency, forKey: UserDefaultsKeys.defaultTargetCurrency)
        userDefaults.set(favoriteCurrencies.elements, forKey: UserDefaultsKeys.favoriteCurrencies)
        userDefaults.set(hasSeenOnboarding, forKey: UserDefaultsKeys.hasSeenOnboarding)
        userDefaults.set(hasSeenChartOnboarding, forKey: UserDefaultsKeys.hasSeenChartOnboarding)
    }

    /// Reset all settings to their default values
    func resetSettingsToDefault() {
        accentColor = DefaultValues.accentColor
        appearanceMode = DefaultValues.appearanceMode
        defaultBaseCurrency = DefaultValues.baseCurrency
        defaultTargetCurrency = DefaultValues.targetCurrency
        favoriteCurrencies = Self.identifiedCurrencies(DefaultValues.favoriteCurrencies)
        hasSeenOnboarding = DefaultValues.hasSeenOnboarding
        hasSeenChartOnboarding = DefaultValues.hasSeenChartOnboarding

        saveSettings()
    }

    // MARK: - Data Management Methods

    /// Wipes all locally stored exchange rate data and rebuilds it. The use case
    /// wipes the repository, signals each feature's reset, and kicks the same tiered
    /// warm-up the app runs at launch; Settings holds no sibling-ViewModel references.
    /// - Returns: true when the wipe succeeded — the caller's toast must not claim a
    ///   refresh that never started.
    @discardableResult
    func refreshAllData() async -> Bool {
        do {
            try await refreshAllDataUseCase.execute()
            logger.info("Data wipe complete; refresh started", category: .viewModel)
            return true
        } catch {
            logger.error("Failed to refresh data: \(error)", category: .viewModel)

            // Use centralized error handler for user feedback
            if let appError = AppError.from(error) {
                appState.errorHandler.handle(appError)
            }
            return false
        }
    }

    // MARK: - Currency Management Methods

    /// Add a currency to favorites if it's not already in the list
    /// - Parameter currency: The currency code to add
    /// - Returns: True if the currency was added, false if it was already in favorites
    @discardableResult
    func addToFavorites(_ currency: String) -> Bool {
        guard CurrencyCode(currency) != nil else { return false }

        // append(_:) is a no-op when the ID is already present.
        let (inserted, _) = favoriteCurrencies.append(currency)
        return inserted
    }

    /// Move currencies within the favorites list
    /// - Parameters:
    ///   - from: The offsets to move from
    ///   - to: The offset to move to
    func moveFavorites(from: IndexSet, to: Int) {
        favoriteCurrencies.move(fromOffsets: from, toOffset: to)
    }

    /// Remove a currency from favorites
    /// - Parameter currency: The currency code to remove
    /// - Returns: True if the currency was removed, false if it wasn't in favorites
    @discardableResult
    func removeFromFavorites(_ currency: String) -> Bool {
        favoriteCurrencies.remove(id: currency) != nil
    }
}
