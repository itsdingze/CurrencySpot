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
    private final class HistoricalCacheBox {
        var storage: [HistoricalRateSnapshot] = []
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

        func fetchExchangeRates() async throws -> [ExchangeRate] {
            MockExchangeRates.getCurrencyRates()
        }

        func loadExchangeRates() async throws -> [ExchangeRate] {
            MockExchangeRates.getCurrencyRates()
        }

        func lastFetchDate() -> Date? {
            today
        }

        // MARK: - HistoricalRateRepository

        func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
            try await generatedHistoricalRates().filter { entry in
                entry.date >= startDate && entry.date <= endDate
            }
        }

        func waitForPendingHistoricalWrites() async {}

        func loadHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
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

        func cachedHistoricalRates() async -> [HistoricalRateSnapshot] {
            cacheBox.storage
        }

        func mergeCachedHistoricalRates(_ new: [HistoricalRateSnapshot]) async -> [HistoricalRateSnapshot] {
            cacheBox.storage = HistoricalRateSnapshot.merge(existing: cacheBox.storage, new: new)
            return cacheBox.storage
        }

        // MARK: - TrendRepository

        func loadTrendData() async throws -> [Trend] {
            Array(MockExchangeRates.trendData.values)
        }

        func saveTrendData(_: [Trend]) async throws {}

        func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
            try await generatedHistoricalRates().filter { entry in
                entry.date >= startDate && entry.date <= endDate
            }
        }

        // MARK: - DataClearing

        func clearAllData() async throws {}

        // MARK: - Fixtures

        /// Generates deterministic mock historical data anchored to `today`.
        private func generatedHistoricalRates() async throws -> [HistoricalRateSnapshot] {
            let calendar = TimeZoneManager.cetCalendar
            var historicalData: [HistoricalRateSnapshot] = []

            for i in 0 ..< 30 { // 30 days of mock data
                if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                    // Fixed per-day drift (±5% over the window) instead of randomness,
                    // so repeated loads return identical series.
                    let variation = 0.95 + Double(i) / 290.0

                    let ratePoints = MockExchangeRates.getCurrencyRates().map { rate in
                        HistoricalRatePoint(
                            currencyCode: rate.currencyCode,
                            rate: rate.rate * variation
                        )
                    }

                    historicalData.append(HistoricalRateSnapshot(date: date, rates: ratePoints))
                }
            }

            return historicalData.sorted { $0.date < $1.date }
        }
    }

#endif
