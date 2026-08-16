import Foundation

protocol ChartDataCacheRepository {
    func cachedChartData(for key: ChartCacheKey) async -> [ChartDataPoint]?

    func storeChartData(_ data: [ChartDataPoint], for key: ChartCacheKey) async
}
