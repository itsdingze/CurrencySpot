#if DEBUG

    import Foundation

    final class InMemoryChartDataCache: ChartDataCacheRepository {
        private var storage: [ChartCacheKey: [ChartDataPoint]] = [:]

        func cachedChartData(for key: ChartCacheKey) async -> [ChartDataPoint]? {
            storage[key]
        }

        func storeChartData(_ data: [ChartDataPoint], for key: ChartCacheKey) async {
            storage[key] = data
        }
    }

#endif
