@testable import CurrencySpot
import Testing

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
