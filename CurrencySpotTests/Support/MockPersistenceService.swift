@testable import CurrencySpot
import Foundation

actor MockPersistenceService: PersistenceService {
    private(set) var savedHistoricalRates: [[String: [String: Double]]] = []
    private(set) var clearAllDataCallCount = 0
    private(set) var savedHistoricalAfterClear = false

    private var saveHistoricalError: Error?

    func stubSaveHistoricalError(_ error: Error?) {
        saveHistoricalError = error
    }

    func saveExchangeRates(_: [String: Double]) async throws {}

    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws {
        if let saveHistoricalError {
            throw saveHistoricalError
        }
        if clearAllDataCallCount > 0 {
            savedHistoricalAfterClear = true
        }
        savedHistoricalRates.append(rates)
    }

    func loadExchangeRates() async throws -> [ExchangeRate] { [] }

    func loadHistoricalRates(from _: Date, to _: Date) async throws -> [HistoricalRateSnapshot] { [] }

    func getEarliestStoredDate() async throws -> Date? { nil }

    func getLatestStoredDate() async throws -> Date? { nil }

    func loadTrendData() async throws -> [Trend] { [] }

    func saveTrendData(_: [Trend]) async throws {}

    func clearAllData() async throws {
        clearAllDataCallCount += 1
    }
}
