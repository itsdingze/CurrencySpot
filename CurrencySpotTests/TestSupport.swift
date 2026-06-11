//
//  TestSupport.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation

/// Builds a Date at midnight CET from calendar components, for use as a test fixture.
func createCETDate(year: Int, month: Int, day: Int) -> Date? {
    let components = DateComponents(
        timeZone: TimeZoneManager.cetTimeZone,
        year: year,
        month: month,
        day: day
    )
    return TimeZoneManager.cetCalendar.date(from: components)
}

/// Builds an environment-isolated CalculatorViewModel: unique UserDefaults suite
/// (never `.standard`) and a non-monitoring AppState, so connectivity and currency
/// preferences are deterministic regardless of the host machine.
@MainActor
func makeIsolatedCalculatorViewModel(
    service: ExchangeRateService = MockExchangeRateService()
) -> CalculatorViewModel {
    let suiteName = "TestSupport.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return CalculatorViewModel(
        service: service,
        appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
        userDefaults: defaults
    )
}
