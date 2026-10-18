import Foundation

protocol HistoricalRateRepository: StoredHistoricalRateRepository {
    func cachedHistoricalRates() async -> [HistoricalRateSnapshot]

    func fetchAndMergeHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot]

    func loadAndMergeStoredHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot]
}
