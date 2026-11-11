import Foundation

extension RateSeries {
    func rateText(in locale: Locale) -> String {
        latestRate?.rateText(in: locale) ?? String(localized: .widgetRateUnavailable, in: locale)
    }

    func changeText(in locale: Locale) -> String? {
        percentChange.map { (abs($0) / 100).formatted(.percent.precision(.fractionLength(2)).locale(locale)) }
    }
}
