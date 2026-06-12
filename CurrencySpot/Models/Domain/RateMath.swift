//
//  RateMath.swift
//  CurrencySpot
//

import Foundation

nonisolated enum RateMath {
    /// Percentage change from `first` to `last`; nil when `first` is zero (undefined).
    static func percentChange(from first: Double, to last: Double) -> Double? {
        guard first != 0 else { return nil }
        return ((last - first) / first) * 100
    }
}
