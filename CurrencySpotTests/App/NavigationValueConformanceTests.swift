//
//  NavigationValueConformanceTests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Testing

/// SwiftUI's navigation machinery matches NavigationLink/Tab values to their
/// destinations through type-erased Hashable casts performed in nonisolated
/// code. Under MainActor default isolation an inferred (isolated) conformance
/// makes that runtime cast fail and the link silently dead-ends, so these
/// types must keep nonisolated conformances. This suite pins that invariant
/// by performing the same cast off the main actor.
nonisolated struct NavigationValueConformanceTests {
    @Test func settingsRouteHashableIsUsableOffMainActor() {
        let route: Any = SettingsRoute.favoriteCurrencies
        #expect((route as? any Hashable) != nil)
    }

    @Test func appTabHashableIsUsableOffMainActor() {
        let tab: Any = AppTab.settings
        #expect((tab as? any Hashable) != nil)
    }
}
