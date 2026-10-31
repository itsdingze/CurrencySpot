import Foundation

// MARK: - UserDefaultsKeys

nonisolated enum UserDefaultsKeys {
    // MARK: - Currency Settings
    
    static let defaultBaseCurrency = "DefaultBaseCurrency"
    static let defaultTargetCurrency = "DefaultTargetCurrency"
    static let favoriteCurrencies = "FavoriteCurrencies"

    static let rateCurrencies = "RateCurrencies"

    static let historyWatchlist = "HistoryWatchlist"
    static let conversionHistory = "ConversionHistory"
    
    // MARK: - Appearance Settings
    
    static let accentColor = "SelectedAccentColor"
    static let appearanceMode = "AppearanceMode"
    
    // MARK: - Network & Data Settings
    
    static let lastFetchDate = "LastFetchDateKey"
    static let historicalSyncFrom = "HistoricalSyncFromDate"
    static let historicalSyncThrough = "HistoricalSyncThroughDate"
    static let historicalSyncCheckedAt = "HistoricalSyncCheckedAt"
    
    // MARK: - Onboarding
    
    static let hasSeenOnboarding = "HasSeenOnboarding"
    static let hasSeenChartOnboarding = "HasSeenChartOnboarding"
}
