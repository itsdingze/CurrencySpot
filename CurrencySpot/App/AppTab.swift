//
//  AppTab.swift
//  CurrencySpot
//

/// App-wide tab identity. Deep links target a tab by name, so the mapping
/// survives tabs being added, removed (camera on unsupported devices), or
/// ordered differently between the modern and legacy hierarchies.
enum AppTab: Hashable {
    case convert
    case camera
    case history
    case settings
}
