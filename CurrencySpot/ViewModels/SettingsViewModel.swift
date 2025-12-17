//
//  SettingsViewModel.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/19/25.
//

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
@MainActor
final class SettingsViewModel {
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

    var favoriteCurrencies: [String] {
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

    private let userDefaults = UserDefaults.standard
    private var isInitializing = true
    private let service: ExchangeRateService
    private let appState = AppState.shared

    // References to ViewModels for clearing data
    private weak var calculatorViewModel: CalculatorViewModel?
    private weak var historyViewModel: HistoryViewModel?

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

    init(service: ExchangeRateService, calculatorViewModel: CalculatorViewModel? = nil, historyViewModel: HistoryViewModel? = nil) {
        self.service = service
        self.calculatorViewModel = calculatorViewModel
        self.historyViewModel = historyViewModel

        // Initialize properties from UserDefaults with optimized access
        // Note: Using "SelectedAccentColor" key for backward compatibility
        accentColor = userDefaults.string(forKey: "SelectedAccentColor")
            .flatMap { AccentColorOption(rawValue: $0) } ?? DefaultValues.accentColor

        appearanceMode = userDefaults.string(forKey: UserDefaultsKeys.appearanceMode)
            .flatMap { AppearanceMode(rawValue: $0) } ?? DefaultValues.appearanceMode

        defaultBaseCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultBaseCurrency) ?? DefaultValues.baseCurrency
        defaultTargetCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultTargetCurrency) ?? DefaultValues.targetCurrency
        favoriteCurrencies = userDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies) ?? DefaultValues.favoriteCurrencies
        hasSeenOnboarding = userDefaults.bool(forKey: UserDefaultsKeys.hasSeenOnboarding)
        hasSeenChartOnboarding = userDefaults.bool(forKey: UserDefaultsKeys.hasSeenChartOnboarding)

        // Setup property observers after initialization
        defer {
            isInitializing = false
        }
    }

    // MARK: - Public Settings Methods

    /// Save all settings to UserDefaults
    /// - Returns: Success or failure
    @discardableResult
    func saveSettings() -> Bool {
        // Note: Using "SelectedAccentColor" key for backward compatibility
        userDefaults.set(accentColor.rawValue, forKey: "SelectedAccentColor")
        userDefaults.set(appearanceMode.rawValue, forKey: UserDefaultsKeys.appearanceMode)
        userDefaults.set(defaultBaseCurrency, forKey: UserDefaultsKeys.defaultBaseCurrency)
        userDefaults.set(defaultTargetCurrency, forKey: UserDefaultsKeys.defaultTargetCurrency)
        userDefaults.set(favoriteCurrencies, forKey: UserDefaultsKeys.favoriteCurrencies)
        userDefaults.set(hasSeenOnboarding, forKey: UserDefaultsKeys.hasSeenOnboarding)
        userDefaults.set(hasSeenChartOnboarding, forKey: UserDefaultsKeys.hasSeenChartOnboarding)

        return true
    }

    /// Reset all settings to their default values
    func resetSettingsToDefault() {
        accentColor = DefaultValues.accentColor
        appearanceMode = DefaultValues.appearanceMode
        defaultBaseCurrency = DefaultValues.baseCurrency
        defaultTargetCurrency = DefaultValues.targetCurrency
        favoriteCurrencies = DefaultValues.favoriteCurrencies
        hasSeenOnboarding = DefaultValues.hasSeenOnboarding
        hasSeenChartOnboarding = DefaultValues.hasSeenChartOnboarding

        saveSettings()
    }

    // MARK: - Data Management Methods

    /// Clear all cached exchange rate data
    func clearCachedData() async {
        do {
            try await service.clearAllData()

            // Clear ViewModels data to prevent stale references
            calculatorViewModel?.clearAllData()
            historyViewModel?.clearAllData()

            AppLogger.info("Cache cleared successfully", category: .viewModel)
        } catch {
            AppLogger.error("Failed to clear cached data: \(error)", category: .viewModel)

            // Use centralized error handler for user feedback
            if let appError = AppError.from(error) {
                appState.errorHandler.handle(appError)
            }
        }
    }

    // MARK: - Currency Management Methods

    /// Add a currency to favorites if it's not already in the list
    /// - Parameter currency: The currency code to add
    /// - Returns: True if the currency was added, false if it was already in favorites
    @discardableResult
    func addToFavorites(_ currency: String) -> Bool {
        // Validate currency code
        guard CurrencyUtilities.shared.isValidCode(currency) else { return false }

        // Check if already in favorites - use more efficient contains check
        guard !favoriteCurrencies.contains(currency) else { return false }

        // Add to favorites
        favoriteCurrencies.append(currency)
        return true
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
        let initialCount = favoriteCurrencies.count
        favoriteCurrencies.removeAll { $0 == currency }
        return favoriteCurrencies.count < initialCount
    }
}
