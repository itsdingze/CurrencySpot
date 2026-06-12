//
//  TrendRepository.swift
//  CurrencySpot
//

import Foundation

/// Trend data aggregate: load/save of computed trends plus the raw historical
/// window the trend calculation consumes. The math itself lives in TrendDataUseCase.
protocol TrendRepository {
    /// Cache-first load of stored trend values.
    func loadTrendData() async throws -> [Trend]

    /// Replaces stored trends with freshly computed values and refreshes the cache.
    func saveTrendData(_ trends: [Trend]) async throws

    /// Raw historical rates (all currencies) within the trend window.
    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot]
}
