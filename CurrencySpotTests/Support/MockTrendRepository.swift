@testable import CurrencySpot
import Foundation

final class MockTrendRepository: TrendRepository {
    var trendsToReturn: [Trend]
    var historicalWindowData: [HistoricalRateSnapshot] = []
    var shouldThrowOnLoadTrends = false
    var shouldThrowOnSave = false
    var errorToThrow: Error = AppError.unknownError("Mock trend error")

    private(set) var loadTrendDataCallCount = 0
    private(set) var saveTrendDataCallCount = 0
    private(set) var loadHistoricalRatesCallCount = 0
    private(set) var lastSavedTrends: [Trend]?

    init(trends: [Trend] = []) {
        trendsToReturn = trends
    }

    func loadTrendData() async throws -> [Trend] {
        loadTrendDataCallCount += 1
        if shouldThrowOnLoadTrends {
            throw errorToThrow
        }
        return trendsToReturn
    }

    func saveTrendData(_ trends: [Trend]) async throws {
        saveTrendDataCallCount += 1
        if shouldThrowOnSave {
            throw errorToThrow
        }
        lastSavedTrends = trends
        trendsToReturn = trends
    }

    func loadHistoricalRates(from _: Date, to _: Date) async throws -> [HistoricalRateSnapshot] {
        loadHistoricalRatesCallCount += 1
        return historicalWindowData
    }
}
