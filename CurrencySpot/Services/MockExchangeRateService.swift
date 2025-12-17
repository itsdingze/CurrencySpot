//
//  MockExchangeRateService.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 6/24/25.
//

import Foundation

/// Mock implementation of ExchangeRateService for previews and testing
/// Returns Value Types only - no SwiftData dependencies
struct MockExchangeRateService: ExchangeRateService {
    // MARK: - Network Methods (Return Mock API Responses)

    func shouldFetchNewRates() async -> Bool {
        false // Always use cached data in previews
    }

    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        ExchangeRatesResponse(
            base: "USD",
            date: "2025-06-24",
            rates: MockExchangeRates.rates
        )
    }

    func fetchHistoricalRates(days: Int) async throws -> HistoricalRatesResponse {
        // Generate mock historical data
        let calendar = Calendar.current
        let today = Date()
        var mockRates: [String: [String: Double]] = [:]

        for i in 0 ..< days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateString = TimeZoneManager.formatForAPI(date)
                // Add some random variation to make it realistic
                let variation = Double.random(in: 0.95 ... 1.05)
                mockRates[dateString] = MockExchangeRates.rates.mapValues { $0 * variation }
            }
        }

        return HistoricalRatesResponse(
            base: "USD",
            start_date: TimeZoneManager.formatForAPI(calendar.date(byAdding: .day, value: -days, to: today) ?? today),
            end_date: TimeZoneManager.formatForAPI(today),
            rates: mockRates
        )
    }

    func fetchHistoricalRatesForRange(startDate: Date, endDate: Date) async throws -> HistoricalRatesResponse {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 7
        return try await fetchHistoricalRates(days: days)
    }

    func fetchAndSaveHistoricalRates(from _: Date, to _: Date) async throws {}

    // MARK: - Save Methods (No-op for Mock)

    func saveExchangeRates(_: [String: Double]) async throws {
        // No-op for mock service
    }

    func saveHistoricalExchangeRates(_: [String: [String: Double]]) async throws {
        // No-op for mock service
    }

    // MARK: - Load Methods (Return Value Types Directly)

    func loadExchangeRates() async throws -> [ExchangeRateDataValue] {
        // ✅ Returns Value Types directly - no SwiftData conversion needed
        MockExchangeRates.getCurrencyRates()
    }

    func loadHistoricalRates() async throws -> [HistoricalRateDataValue] {
        // Generate mock historical data as Value Types
        let calendar = Calendar.current
        let today = Date()
        var historicalData: [HistoricalRateDataValue] = []

        for i in 0 ..< 30 { // 30 days of mock data
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateString = TimeZoneManager.formatForAPI(date)
                let variation = Double.random(in: 0.95 ... 1.05)

                let ratePoints = MockExchangeRates.rates.map { currency, rate in
                    HistoricalRateDataPointValue(
                        currencyCode: currency,
                        rate: rate * variation
                    )
                }

                let historicalEntry = try HistoricalRateDataValue(
                    dateString: dateString,
                    rates: ratePoints
                )

                historicalData.append(historicalEntry)
            }
        }

        return historicalData.sorted { $0.date < $1.date }
    }

    func loadHistoricalRatesForCurrency(currency _: String, startDate: String, endDate: String) async throws -> [HistoricalRateDataValue] {
        // For mock, just return filtered data
        let allData = try await loadHistoricalRates()

        guard let startDateObj = TimeZoneManager.parseAPIDate(startDate),
              let endDateObj = TimeZoneManager.parseAPIDate(endDate)
        else {
            return []
        }

        return allData.filter { entry in
            entry.date >= startDateObj && entry.date <= endDateObj
        }
    }

    // MARK: - Date Management (Mock Implementation)

    func updateLastFetchDate(_: Date) {
        // Could store in memory for more realistic mock behavior
    }

    func getEarliestStoredDate() async throws -> Date? {
        // Always return current date for mock
        Date()
    }

    func getLatestStoredDate() async throws -> Date? {
        Date()
    }

    func getLastFetchDate() -> Date? {
        Date() // Always return current date for mock
    }

    // MARK: - Trend Data Methods

    func loadTrendData() async throws -> [TrendDataValue] {
        // Return mock trend data as TrendDataValue instances for testing
        Array(MockExchangeRates.trendData.values)
    }

    func calculateAndSaveTrendData() async throws {
        // No-op for mock service - trends are pre-calculated
    }

    func hasSufficientHistoricalDataForTrends() async throws -> Bool {
        // Mock service always has sufficient data
        true
    }

    func doesDateRangeAffectTrends(startDate: Date, endDate: Date) async throws -> Bool {
        // For mock service, assume any date range in the last 7 days affects trends
        let calendar = Calendar.current
        let now = Date()
        let trendWindowStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return startDate <= now && endDate >= trendWindowStart
    }

    func clearAllData() async throws {
        // No-op for mock service
    }
}

// MARK: - Updated Preview Methods

extension CalculatorViewModel {
    static func preview() -> CalculatorViewModel {
        let mockService = MockExchangeRateService()
        return CalculatorViewModel(service: mockService)
    }
}

extension HistoryViewModel {
    static func preview() -> HistoryViewModel {
        let mockService = MockExchangeRateService()
        let calculatorVM = CalculatorViewModel(service: mockService)
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: InMemoryCacheService()
        )
        let cacheService = InMemoryCacheService()
        let rateCalculationUseCase = RateCalculationUseCase()
        let chartDataPreparationUseCase = ChartDataPreparationUseCase(
            rateCalculationUseCase: rateCalculationUseCase,
            cacheService: cacheService
        )
        let trendDataUseCase = TrendDataUseCase(service: mockService)

        return HistoryViewModel(
            service: mockService,
            calculatorVM: calculatorVM,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase
        )
    }
}

extension SettingsViewModel {
    static func preview() -> SettingsViewModel {
        let mockService = MockExchangeRateService()
        return SettingsViewModel(service: mockService)
    }
}
