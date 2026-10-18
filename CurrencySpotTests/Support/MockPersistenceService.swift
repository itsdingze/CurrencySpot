@testable import CurrencySpot
import Foundation

actor MockPersistenceService: PersistenceService {
    private(set) var savedHistoricalRates: [[String: [String: Double]]] = []
    private(set) var clearAllDataCallCount = 0
    private(set) var savedHistoricalAfterClear = false

    private var storedHistory: [Date: [String: Double]] = [:]
    private var saveHistoricalError: Error?

    func stubSaveHistoricalError(_ error: Error?) {
        saveHistoricalError = error
    }

    func saveExchangeRates(_: [ExchangeRate]) async throws {}

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
        for (dayString, dayRates) in rates {
            guard let day = CETCalendar.date(fromDayString: dayString), storedHistory[day] == nil else { continue }
            storedHistory[day] = dayRates
        }
    }

    func loadExchangeRates() async throws -> [ExchangeRate] { [] }

    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        storedHistory
            .filter { $0.key >= startDate && $0.key <= endDate }
            .map { day, rates in
                HistoricalRateSnapshot(
                    date: day,
                    rates: rates.compactMap { code, rate in
                        CurrencyCode(code).map { HistoricalRatePoint(currencyCode: $0, rate: rate) }
                    }
                )
            }
            .sorted { $0.date < $1.date }
    }

    func getEarliestStoredDate() async throws -> Date? {
        storedHistory.keys.min()
    }

    func getLatestStoredDate() async throws -> Date? {
        storedHistory.keys.max()
    }

    func deleteHistoricalRates(before cutoff: Date) async throws {
        storedHistory = storedHistory.filter { $0.key >= cutoff }
    }

    func loadTrendData() async throws -> [Trend] { [] }

    func saveTrendData(_: [Trend]) async throws {}

    func clearAllData() async throws {
        clearAllDataCallCount += 1
        storedHistory = [:]
    }
}
