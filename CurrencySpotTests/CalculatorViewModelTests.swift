//
//  CalculatorViewModelTests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation
import Testing

// MARK: - Test Double

/// Configurable ExchangeRateService double for CalculatorViewModel tests.
private final class StubExchangeRateService: ExchangeRateService {
    var shouldFetchNewRatesResult = false
    var fetchExchangeRatesResult: Result<ExchangeRatesResponse, AppError> =
        .success(ExchangeRatesResponse(base: "USD", date: "2025-01-15", rates: ["EUR": 0.9]))
    var loadExchangeRatesResult: Result<[ExchangeRateDataValue], AppError> = .success([])

    private(set) var fetchExchangeRatesCallCount = 0
    private(set) var loadExchangeRatesCallCount = 0
    private(set) var savedRates: [String: Double]?
    private(set) var lastFetchDate: Date?

    func shouldFetchNewRates() async -> Bool { shouldFetchNewRatesResult }

    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        fetchExchangeRatesCallCount += 1
        return try fetchExchangeRatesResult.get()
    }

    func fetchAndSaveHistoricalRates(from _: Date, to _: Date) async throws {}
    func saveExchangeRates(_ rates: [String: Double]) async throws { savedRates = rates }
    func saveHistoricalExchangeRates(_: [String: [String: Double]]) async throws {}

    func loadExchangeRates() async throws -> [ExchangeRateDataValue] {
        loadExchangeRatesCallCount += 1
        return try loadExchangeRatesResult.get()
    }

    func loadHistoricalRatesForCurrency(currency _: String, startDate _: String, endDate _: String) async throws -> [HistoricalRateDataValue] { [] }
    func updateLastFetchDate(_ date: Date) { lastFetchDate = date }
    func getLastFetchDate() -> Date? { lastFetchDate }
    func getEarliestStoredDate() async throws -> Date? { nil }
    func getLatestStoredDate() async throws -> Date? { nil }
    func loadTrendData() async throws -> [TrendDataValue] { [] }
    func calculateAndSaveTrendData() async throws {}
    func hasSufficientHistoricalDataForTrends() async throws -> Bool { true }
    func doesDateRangeAffectTrends(startDate _: Date, endDate _: Date) async throws -> Bool { false }
    func clearAllData() async throws {}
}

// MARK: - Tests

@Suite("CalculatorViewModel Tests")
@MainActor
struct CalculatorViewModelTests {
    private let service = StubExchangeRateService()
    private let appState = AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false))

    private func makeViewModel() throws -> CalculatorViewModel {
        let suiteName = "CalculatorViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return CalculatorViewModel(service: service, appState: appState, userDefaults: defaults)
    }

    /// Yields the main actor until `condition` holds, letting the view model's
    /// internal fetch task (also main-actor) run to completion. Callers guard
    /// against hangs with `.timeLimit`.
    private func waitUntil(_ condition: () -> Bool) async {
        while condition() == false {
            await Task.yield()
        }
    }

    // MARK: Initialization

    @Test("initializes with currencies from the injected defaults, falling back to USD/EUR")
    func initializesWithDefaults() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.targetCurrency == "EUR")
        #expect(viewModel.isLoading == true)
        #expect(viewModel.availableRates.isEmpty)
    }

    @Test("initializes with stored currency preferences when present")
    func initializesWithStoredPreferences() throws {
        let suiteName = "CalculatorViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("CHF", forKey: UserDefaultsKeys.defaultBaseCurrency)
        defaults.set("CAD", forKey: UserDefaultsKeys.defaultTargetCurrency)

        let viewModel = CalculatorViewModel(service: service, appState: appState, userDefaults: defaults)

        #expect(viewModel.baseCurrency == "CHF")
        #expect(viewModel.targetCurrency == "CAD")
    }

    // MARK: inputAmount semantics

    @Test("inputAmountString is cents-style: the last two digits are the fraction", arguments: [
        ("0", 0.0),
        ("5", 0.05),
        ("100", 1.0),
        ("1234", 12.34),
        ("999999", 9999.99),
        ("not-a-number", 0.0),
    ])
    func inputAmountParsesCentsStyle(input: String, expected: Double) throws {
        let viewModel = try makeViewModel()
        viewModel.inputAmountString = input
        #expect(abs(viewModel.inputAmount - expected) < 0.0001)
    }

    // MARK: conversionRate math

    @Test("conversionRate is target rate divided by base rate from availableRates")
    func conversionRateUsesAvailableRates() throws {
        let viewModel = try makeViewModel()
        viewModel.availableRates = [
            ExchangeRateDataValue(currencyCode: "USD", rate: 1.0),
            ExchangeRateDataValue(currencyCode: "EUR", rate: 0.8),
            ExchangeRateDataValue(currencyCode: "GBP", rate: 0.5),
        ]
        viewModel.baseCurrency = "EUR"
        viewModel.targetCurrency = "GBP"
        #expect(abs(viewModel.conversionRate - 0.625) < 0.0001) // 0.5 / 0.8
    }

    @Test("conversionRate is 1.0 when base and target are the same currency")
    func conversionRateSameCurrencyIsOne() throws {
        let viewModel = try makeViewModel()
        viewModel.availableRates = [ExchangeRateDataValue(currencyCode: "EUR", rate: 0.8)]
        viewModel.baseCurrency = "EUR"
        viewModel.targetCurrency = "EUR"
        #expect(viewModel.conversionRate == 1.0)
    }

    @Test("a currency missing from availableRates falls back to a rate of 1.0")
    func conversionRateMissingCurrencyFallsBack() throws {
        let viewModel = try makeViewModel()
        viewModel.availableRates = [ExchangeRateDataValue(currencyCode: "USD", rate: 1.0)]
        viewModel.baseCurrency = "USD"
        viewModel.targetCurrency = "ZZZ" // unknown → treated as 1.0
        #expect(viewModel.conversionRate == 1.0)
    }

    // MARK: convertedAmount formatting

    @Test("convertedAmount formats with exactly two fraction digits")
    func convertedAmountFormatting() throws {
        let viewModel = try makeViewModel()
        viewModel.availableRates = [
            ExchangeRateDataValue(currencyCode: "USD", rate: 1.0),
            ExchangeRateDataValue(currencyCode: "EUR", rate: 0.85),
        ]
        viewModel.baseCurrency = "USD"
        viewModel.targetCurrency = "EUR"
        viewModel.inputAmountString = "1000" // 10.00

        #expect(viewModel.convertedAmount == "8.50") // locale pinned to en_US by the test plan
    }

    // MARK: Fetch lifecycle

    @Test("checkIfShouldFetch fetches when rates are stale and the device is connected", .timeLimit(.minutes(1)))
    func staleAndConnectedFetches() async throws {
        let viewModel = try makeViewModel()
        service.shouldFetchNewRatesResult = true
        appState.networkMonitor.isConnected = true
        service.fetchExchangeRatesResult = .success(
            ExchangeRatesResponse(base: "USD", date: "2025-01-15", rates: ["EUR": 0.9])
        )

        await viewModel.checkIfShouldFetch()
        await waitUntil { viewModel.isLoading == false }

        #expect(service.fetchExchangeRatesCallCount == 1)
        #expect(viewModel.availableRates.contains { $0.currencyCode == "EUR" && $0.rate == 0.9 })
        #expect(viewModel.availableRates.contains { $0.currencyCode == "USD" && $0.rate == 1.0 })
        #expect(viewModel.lastUpdated != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(service.savedRates?["EUR"] == 0.9)
    }

    @Test("checkIfShouldFetch loads from cache when rates are fresh")
    func freshLoadsFromCache() async throws {
        let viewModel = try makeViewModel()
        service.shouldFetchNewRatesResult = false
        appState.networkMonitor.isConnected = true
        service.loadExchangeRatesResult = .success([ExchangeRateDataValue(currencyCode: "EUR", rate: 0.88)])

        await viewModel.checkIfShouldFetch()

        #expect(service.fetchExchangeRatesCallCount == 0)
        #expect(viewModel.availableRates.count == 1)
        #expect(viewModel.availableRates.first?.rate == 0.88)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isUsingMockData == false)
    }

    @Test("a failing fetch falls back to cached data", .timeLimit(.minutes(1)))
    func failedFetchFallsBackToCache() async throws {
        let viewModel = try makeViewModel()
        service.shouldFetchNewRatesResult = true
        appState.networkMonitor.isConnected = true
        service.fetchExchangeRatesResult = .failure(.networkError("stubbed failure"))
        service.loadExchangeRatesResult = .success([ExchangeRateDataValue(currencyCode: "GBP", rate: 0.75)])

        await viewModel.checkIfShouldFetch()
        await waitUntil { viewModel.isLoading == false }

        #expect(service.fetchExchangeRatesCallCount == 1)
        #expect(viewModel.availableRates.count == 1)
        #expect(viewModel.availableRates.first?.currencyCode == "GBP")
        #expect(viewModel.isUsingMockData == false)
    }

    @Test("offline with no cached data falls back to mock data")
    func offlineWithoutCacheUsesMockData() async throws {
        let viewModel = try makeViewModel()
        service.shouldFetchNewRatesResult = true
        appState.networkMonitor.isConnected = false
        service.loadExchangeRatesResult = .failure(.noCachedData)

        await viewModel.checkIfShouldFetch()

        #expect(service.fetchExchangeRatesCallCount == 0)
        #expect(viewModel.isUsingMockData == true)
        #expect(viewModel.availableRates.count == MockExchangeRates.rates.count)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test(
        "online with a failing fetch AND failing cache ends loading with an error state (no deadlock)",
        .timeLimit(.minutes(1))
    )
    func onlineFetchAndCacheBothFailEndsLoading() async throws {
        // Phase-B regression: this path previously re-entered the fetch pipeline and
        // self-deadlocked awaiting its own fetchTask.
        let viewModel = try makeViewModel()
        service.shouldFetchNewRatesResult = true
        appState.networkMonitor.isConnected = true
        service.fetchExchangeRatesResult = .failure(.networkError("stubbed fetch failure"))
        service.loadExchangeRatesResult = .failure(.noCachedData)

        await viewModel.checkIfShouldFetch()
        await waitUntil { viewModel.isLoading == false }

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.availableRates.isEmpty)
        #expect(viewModel.isUsingMockData == false)
    }

    // MARK: clearAllData

    @Test("clearAllData resets rates, dates, errors, and loading state")
    func clearAllDataResetsState() async throws {
        let viewModel = try makeViewModel()
        service.loadExchangeRatesResult = .success([ExchangeRateDataValue(currencyCode: "EUR", rate: 0.9)])
        await viewModel.checkIfShouldFetch()
        try #require(viewModel.availableRates.isEmpty == false)

        viewModel.clearAllData()

        #expect(viewModel.availableRates.isEmpty)
        #expect(viewModel.lastUpdated == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isUsingMockData == false)
        guard case .none = viewModel.retryState else {
            Issue.record("retryState should be .none after clearAllData, got \(viewModel.retryState)")
            return
        }
    }
}
