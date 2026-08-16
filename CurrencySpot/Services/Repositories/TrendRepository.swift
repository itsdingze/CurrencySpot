import Foundation

protocol TrendRepository {
    func loadTrendData() async throws -> [Trend]

    func saveTrendData(_ trends: [Trend]) async throws

    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot]
}
