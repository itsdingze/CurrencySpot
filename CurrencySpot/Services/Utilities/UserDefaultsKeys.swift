//
//  UserDefaultsKeys.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 9/14/25.
//

import Foundation

// MARK: - UserDefaultsKeys

/// Type-safe UserDefaults keys to avoid string literals throughout the codebase
enum UserDefaultsKeys {
    // MARK: - Currency Settings
    
    static let defaultBaseCurrency = "DefaultBaseCurrency"
    static let defaultTargetCurrency = "DefaultTargetCurrency"
    static let favoriteCurrencies = "FavoriteCurrencies"
    
    // MARK: - Appearance Settings
    
    static let accentColor = "AccentColor"
    static let appearanceMode = "AppearanceMode"
    
    // MARK: - Network & Data Settings
    
    static let lastFetchDate = "LastFetchDateKey"
    
    // MARK: - Onboarding
    
    static let hasSeenOnboarding = "HasSeenOnboarding"
    static let hasSeenChartOnboarding = "HasSeenChartOnboarding"
}