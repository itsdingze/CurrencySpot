import Foundation

nonisolated enum RateMath {
    static func percentChange(from first: Double, to last: Double) -> Double? {
        guard first != 0 else { return nil }
        return ((last - first) / first) * 100
    }

    static func priceChange(rate: Double, percentChange: Double) -> Double {
        rate * percentChange / 100
    }
}
