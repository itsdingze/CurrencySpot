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

    private var historicalSaveGates: [Int: AsyncStream<Void>] = [:]
    private(set) var historicalSaveAttempts = 0

    func gateHistoricalSave(number: Int, on gate: AsyncStream<Void>) {
        historicalSaveGates[number] = gate
    }

    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws {
        historicalSaveAttempts += 1
        if let gate = historicalSaveGates[historicalSaveAttempts] {
            for await _ in gate {}
        }
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

    func deleteHistoricalRates(before _: Date) async throws {}

    func loadTrendData() async throws -> [Trend] { [] }

    func saveTrendData(_: [Trend]) async throws {}

    func clearAllData() async throws {
        clearAllDataCallCount += 1
    }
}
