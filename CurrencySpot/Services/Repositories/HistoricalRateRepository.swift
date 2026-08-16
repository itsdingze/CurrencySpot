import Foundation

protocol HistoricalRateRepository {
    func fetchHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot]

    func waitForPendingHistoricalWrites() async

    func fetchTransientHistoricalRates(for currencies: [CurrencyCode], in range: DateRange) async throws -> [HistoricalRateSnapshot]

    func fetchAndPersistHistoricalRates(in range: DateRange) async throws

    func loadHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot]

    func earliestStoredDate() async throws -> Date?
    func latestStoredDate() async throws -> Date?

    func cachedHistoricalRates() async -> [HistoricalRateSnapshot]

    func mergeCachedHistoricalRates(_ new: [HistoricalRateSnapshot]) async -> [HistoricalRateSnapshot]
}
