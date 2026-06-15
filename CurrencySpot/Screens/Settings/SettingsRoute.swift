//
//  SettingsRoute.swift
//  CurrencySpot
//

/// Value-based navigation targets for the Settings stack.
/// nonisolated: SwiftUI matches NavigationLink values to destinations via
/// type-erased Hashable casts in nonisolated code; a MainActor-isolated
/// conformance (the module default) fails that cast and dead-ends the link.
nonisolated enum SettingsRoute: Hashable {
    case defaultBaseCurrency
    case defaultTargetCurrency
    case favoriteCurrencies
    case acknowledgements
}
