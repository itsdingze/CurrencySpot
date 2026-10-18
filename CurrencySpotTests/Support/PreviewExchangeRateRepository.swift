@testable import CurrencySpot
import Foundation

private final class HistoricalSeriesBox {
    var storage: [HistoricalRateSnapshot] = []
}

struct PreviewExchangeRateRepository: ExchangeRateRepository, HistoricalRateRepository, ArchiveRepository, TrendRepository, DataClearing {
    private let today: Date
    private let series = HistoricalSeriesBox()

    init(today: Date) {
        self.today = today
    }

    // MARK: - ExchangeRateRepository

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

    func cachedHistoricalRates() async -> [HistoricalRateSnapshot] {
        series.storage
    }

    func fetchAndMergeHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        mergedIntoSeries(generatedHistoricalRates(in: range))
    }

    func loadAndMergeStoredHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        mergedIntoSeries(generatedHistoricalRates(in: range))
    }

    private func mergedIntoSeries(_ rows: [HistoricalRateSnapshot]) -> [HistoricalRateSnapshot] {
        series.storage = HistoricalRateSnapshot.merge(existing: series.storage, new: rows)
        return rows
    }

    // MARK: - StoredHistoricalRateRepository

    func loadStoredHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        generatedHistoricalRates(in: range)
    }

    func earliestStoredDate() async throws -> Date? {
        today
    }

    func latestStoredDate() async throws -> Date? {
        today
    }

    // MARK: - ArchiveRepository

    func fetchTransientHistoricalRates(for currencies: [CurrencyCode], in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        generatedHistoricalRates(in: range).map { day in
            HistoricalRateSnapshot(date: day.date, rates: day.rates.filter { currencies.contains($0.currencyCode) })
        }
    }

    func fetchAndPersistHistoricalRates(in _: DateRange) async throws {}

    func pruneHistoricalRates(before _: Date) async throws {}

    func archiveStoredBounds() async throws -> (earliest: Date?, latest: Date?) {
        (today, today)
    }

    // MARK: - TrendRepository

    func loadTrendData() async throws -> [Trend] {
        SampleExchangeRates.trendData
    }

    func saveTrendData(_: [Trend]) async throws {}

    // MARK: - DataClearing

    func clearAllData() async throws {}

    // MARK: - Fixtures

    private func generatedHistoricalRates(in range: DateRange) -> [HistoricalRateSnapshot] {
        let calendar = CETCalendar.calendar
        var historicalData: [HistoricalRateSnapshot] = []

        for i in 0 ..< 30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today), date >= range.start, date <= range.end {
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
