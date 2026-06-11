//
//  MockExchangeRateService.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 6/24/25.
//

#if DEBUG

    import Foundation

    /// Mock repository implementation for previews and testing.
    /// Returns value types only — no SwiftData dependencies.
    ///
    /// Fully deterministic: all generated series derive from fixed fixture values and the
    /// injected `today` anchor, so the same inputs always produce the same outputs.
    /// Reference storage so the value-typed mock can honor the repository's
    /// cache read/write contract (orchestration round-trips merged data through it).
    private final class HistoricalCacheBox: @unchecked Sendable {
        var storage: [CurrencyCode: [HistoricalRateDataValue]] = [:]
    }

    struct MockExchangeRateService: ExchangeRateRepository, HistoricalRateRepository, TrendRepository, DataClearing {
        /// Anchor for all relative-date fixtures. Defaults to the live clock so
        /// previews stay current; tests inject a fixed date for reproducible series.
        private let today: Date
        private let cacheBox = HistoricalCacheBox()

        init(today: Date = Date()) {
            self.today = today
        }

        // MARK: - ExchangeRateRepository

        func shouldRefreshRates() async -> Bool {
            false // Always use cached data in previews
        }

        func fetchExchangeRates() async throws -> [ExchangeRateDataValue] {
            MockExchangeRates.getCurrencyRates()
        }

        func loadExchangeRates() async throws -> [ExchangeRateDataValue] {
            MockExchangeRates.getCurrencyRates()
        }

        func lastFetchDate() -> Date? {
            today
        }

        // MARK: - HistoricalRateRepository

        func fetchAndSaveHistoricalRates(from _: Date, to _: Date) async throws {}

        func loadHistoricalRates(for _: CurrencyCode, in range: DateRange) async throws -> [HistoricalRateDataValue] {
            try await generatedHistoricalRates().filter { entry in
                entry.date >= range.start && entry.date <= range.end
            }
        }

        func earliestStoredDate() async throws -> Date? {
            today
        }

        func latestStoredDate() async throws -> Date? {
            today
        }

        func cachedHistoricalRates(for currency: CurrencyCode) async -> [HistoricalRateDataValue] {
            cacheBox.storage[currency] ?? []
        }

        func replaceCachedHistoricalRates(_ data: [HistoricalRateDataValue], for currency: CurrencyCode) async {
            cacheBox.storage[currency] = data
        }

        // MARK: - TrendRepository

        func loadTrendData() async throws -> [TrendDataValue] {
            Array(MockExchangeRates.trendData.values)
        }

        func saveTrendData(_: [TrendDataValue]) async throws {}

        func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateDataValue] {
            try await generatedHistoricalRates().filter { entry in
                entry.date >= startDate && entry.date <= endDate
            }
        }

        // MARK: - DataClearing

        func clearAllData() async throws {}

        // MARK: - Fixtures

        /// Generates deterministic mock historical data anchored to `today`.
        private func generatedHistoricalRates() async throws -> [HistoricalRateDataValue] {
            let calendar = TimeZoneManager.cetCalendar
            var historicalData: [HistoricalRateDataValue] = []

            for i in 0 ..< 30 { // 30 days of mock data
                if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                    // Fixed per-day drift (±5% over the window) instead of randomness,
                    // so repeated loads return identical series.
                    let variation = 0.95 + Double(i) / 290.0

                    let ratePoints = MockExchangeRates.getCurrencyRates().map { rate in
                        HistoricalRateDataPointValue(
                            currencyCode: rate.currencyCode,
                            rate: rate.rate * variation
                        )
                    }

                    historicalData.append(HistoricalRateDataValue(date: date, rates: ratePoints))
                }
            }

            return historicalData.sorted { $0.date < $1.date }
        }
    }

#endif
