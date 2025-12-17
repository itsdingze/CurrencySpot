//
//  CurrencyUtilities.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 6/22/25.
//

import Foundation

/// Centralized currency-related utilities and helpers
final class CurrencyUtilities {
    static let shared = CurrencyUtilities()

    private init() {}

    // MARK: - Private Caches

    private var currencyNameCache = [String: String]()
    private var currencySymbolCache = [String: String]()

    // MARK: - Public Methods

    /// Get the localized currency name for a given currency code
    /// - Parameter code: The ISO currency code (e.g., "USD", "EUR")
    /// - Returns: Localized currency name or the code itself if not found
    func name(for code: String) -> String {
        // Check cache first
        if let cachedName = currencyNameCache[code] {
            return cachedName
        }

        let locale = NSLocale.current
        let name: String

        if let localName = locale.localizedString(forCurrencyCode: code) {
            name = localName
        } else {
            // Fallback to English locale if current locale doesn't have the currency
            let enLocale = NSLocale(localeIdentifier: "en_US")
            name = enLocale.displayName(forKey: .currencyCode, value: code) ?? code
        }

        // Update cache
        currencyNameCache[code] = name
        return name
    }

    /// Get the currency symbol for a given currency code
    /// - Parameter code: The ISO currency code (e.g., "USD", "EUR")
    /// - Returns: Currency symbol or the code itself if not found
    func symbol(for code: String) -> String {
        // Check cache first
        if let cachedSymbol = currencySymbolCache[code] {
            return cachedSymbol
        }

        let locale = NSLocale(localeIdentifier: code)
        let symbol = locale.displayName(forKey: .currencySymbol, value: code) ?? code

        // Update cache
        currencySymbolCache[code] = symbol
        return symbol
    }

    /// Check if a string is a valid ISO currency code
    /// - Parameter code: The string to validate
    /// - Returns: True if the code is valid (3 uppercase letters)
    func isValidCode(_ code: String) -> Bool {
        code.count == 3 && code.uppercased() == code && code.allSatisfy(\.isLetter)
    }
}
