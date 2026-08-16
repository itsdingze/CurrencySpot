#if DEBUG

    import Foundation

    private final class HistoricalCacheBox {
        var storage: [HistoricalRateSnapshot] = []
    }

    struct PreviewExchangeRateRepository: ExchangeRateRepository, HistoricalRateRepository, TrendRepository, DataClearing {
        private let today: Date
        private let cacheBox = HistoricalCacheBox()

        init(today: Date = Date()) {
            self.today = today
        }

        // MARK: - ExchangeRateRepository

        func shouldRefreshRates() async -> Bool {
            false
        }

        func fetchExchangeRates() async throws -> [ExchangeRate] {
            SampleExchangeRates.getCurrencyRates()
        }

        func loadExchangeRates() async throws -> [ExchangeRate] {
            SampleExchangeRates.getCurrencyRates()
        }

        func lastFetchDate() -> Date? {
            today
        }

        // MARK: - HistoricalRateRepository

        func fetchHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
            try await generatedHistoricalRates().filter { entry in
                entry.date >= range.start && entry.date <= range.end
            }
        }

        func waitForPendingHistoricalWrites() async {}

        func fetchAndPersistHistoricalRates(in _: DateRange) async throws {}

        func fetchTransientHistoricalRates(for currencies: [CurrencyCode], in range: DateRange) async throws -> [HistoricalRateSnapshot] {
            try await generatedHistoricalRates()
                .filter { $0.date >= range.start && $0.date <= range.end }
                .map { day in
                    HistoricalRateSnapshot(date: day.date, rates: day.rates.filter { currencies.contains($0.currencyCode) })
                }
        }

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
            SampleExchangeRates.trendData
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

        private func generatedHistoricalRates() async throws -> [HistoricalRateSnapshot] {
            let calendar = TimeZoneManager.cetCalendar
            var historicalData: [HistoricalRateSnapshot] = []

            for i in 0 ..< 30 {
                if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                    let variation = 0.95 + Double(i) / 290.0

                    let ratePoints = SampleExchangeRates.getCurrencyRates().map { rate in
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
