//
//  CurrencyUtilities.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 6/22/25.
//

import Foundation

/// Localized currency display-name lookup.
/// MainActor (via default isolation) guards the in-memory cache; all call sites are main-actor UI code.
enum CurrencyUtilities {
    private static var currencyNameCache = [String: String]()

    /// Localized currency name for an ISO code, falling back to en_US, then the code itself.
    static func name(for code: String) -> String {
        if let cachedName = currencyNameCache[code] {
            return cachedName
        }

        let name: String
        if let localName = NSLocale.current.localizedString(forCurrencyCode: code) {
            name = localName
        } else {
            let enLocale = NSLocale(localeIdentifier: "en_US")
            name = enLocale.displayName(forKey: .currencyCode, value: code) ?? code
        }

        currencyNameCache[code] = name
        return name
    }
}
