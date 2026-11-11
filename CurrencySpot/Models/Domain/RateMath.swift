import Foundation

nonisolated enum RateMath {
    static func percentChange(from first: Double, to last: Double) -> Double? {
        guard first != 0 else { return nil }
        return ((last - first) / first) * 100
    }

    static func priceChange(rate: Double, percentChange: Double) -> Double {
        let firstRateShare = 100 + percentChange
        guard firstRateShare != 0 else { return 0 }
        return rate * percentChange / firstRateShare
    }
}
