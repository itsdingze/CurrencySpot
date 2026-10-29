import Foundation

extension RateSeries {
    var rateText: String {
        latestRate?.toStringMax4Decimals ?? String(localized: .widgetRateUnavailable)
    }

    var changeText: String? {
        percentChange.map { (abs($0) / 100).formatted(.percent.precision(.fractionLength(2))) }
    }
}
