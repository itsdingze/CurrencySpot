import Foundation

protocol StoredHistoricalRateRepository {
    func loadStoredHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot]

    func earliestStoredDate() async throws -> Date?
    func latestStoredDate() async throws -> Date?
}
