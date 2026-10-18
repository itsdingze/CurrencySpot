import Foundation

protocol ArchiveRepository: StoredHistoricalRateRepository {
    func fetchTransientHistoricalRates(for currencies: [CurrencyCode], in range: DateRange) async throws -> [HistoricalRateSnapshot]

    func fetchAndPersistHistoricalRates(in range: DateRange) async throws

    func pruneHistoricalRates(before cutoff: Date) async throws

    func archiveStoredBounds() async throws -> (earliest: Date?, latest: Date?)
}
