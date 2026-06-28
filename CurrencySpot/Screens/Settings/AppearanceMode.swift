//
//  AppearanceMode.swift
//  CurrencySpot
//

import Foundation

/// Appearance mode options.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}
