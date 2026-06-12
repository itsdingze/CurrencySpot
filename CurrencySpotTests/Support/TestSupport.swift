//
//  TestSupport.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation

// MARK: - CurrencyCode Test Ergonomics

/// Test-target-only sugar so fixtures can write "EUR" where a CurrencyCode is
/// expected. Force-validation is intentional: a bad literal is a broken fixture.
extension CurrencyCode: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = try! CurrencyCode(validating: value)
    }
}

// MARK: - Date Fixtures

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

// MARK: - Deterministic Infrastructure

/// DateProvider pinned to a single instant.
struct FixedDateProvider: DateProvider {
    let fixedNow: Date

    init(_ fixedNow: Date) {
        self.fixedNow = fixedNow
    }

    func now() -> Date {
        fixedNow
    }
}

/// ClockService that returns immediately, so dismiss delays and backoffs are instant.
struct ImmediateClock: ClockService {
    func sleep(for _: Duration) async throws {}
}

// MARK: - ViewModel Factories

/// Builds an environment-isolated CalculatorViewModel: unique UserDefaults suite
/// (never `.standard`) and a non-monitoring AppState, so connectivity and currency
/// preferences are deterministic regardless of the host machine.
func makeIsolatedCalculatorViewModel(
    repository: (ExchangeRateRepository)? = nil,
    ratesStore: ExchangeRatesStore? = nil,
    appState: AppState? = nil
) -> CalculatorViewModel {
    let repository = repository ?? MockExchangeRateService()
    let ratesStore = ratesStore ?? ExchangeRatesStore()
    let suiteName = "TestSupport.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return CalculatorViewModel(
        repository: repository,
        ratesStore: ratesStore,
        appState: appState ?? AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
        userDefaults: defaults
    )
}
