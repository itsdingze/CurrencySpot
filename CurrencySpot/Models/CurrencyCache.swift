//
//  CurrencyCache.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import Foundation

/// Cached historical data for one currency with precomputed range metadata.
///
/// Performance: currency switching stays O(1) by reading the precomputed earliest/latest
/// dates instead of re-sorting all cached points on every gap-detection pass.
/// Callers must construct this with chronologically sorted data (as `mergeHistoricalData` produces).
final class CurrencyCache {
    let data: [HistoricalRateDataValue]

    var earliestDate: Date? { data.first?.date }
    var latestDate: Date? { data.last?.date }
    var isEmpty: Bool { data.isEmpty }

    init(data: [HistoricalRateDataValue]) {
        self.data = data
    }
}
