import Foundation

extension RateSeries {
    var rateText: String {
        latestRate?.rateText ?? String(localized: .widgetRateUnavailable)
    }

    var changeText: String? {
        percentChange.map { (abs($0) / 100).formatted(.percent.precision(.fractionLength(2))) }
    }
}
