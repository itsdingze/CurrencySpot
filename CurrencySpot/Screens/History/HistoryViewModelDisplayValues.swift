import Foundation

extension HistoryViewModel {
    // MARK: - Statistics

    var currentRate: Double {
        chartStatistics.currentRate
    }

    var highestRate: Double {
        chartStatistics.highestRate
    }

    var lowestRate: Double {
        chartStatistics.lowestRate
    }

    var averageRate: Double {
        chartStatistics.averageRate
    }

    var priceChange: Double? {
        chartStatistics.priceChange
    }

    var percentChange: Double? {
        chartStatistics.percentChange
    }

    var trendDirection: TrendDirection {
        chartStatistics.trendDirection
    }

    var volatility: Double? {
        chartStatistics.volatility
    }

    // MARK: - Formatted Display Values

    var formattedCurrentRate: String {
        "1 \(baseCurrency.rawValue) = \(currentRate.toStringMax4Decimals) \(targetCurrency.rawValue)"
    }

    var formattedHighestRate: String {
        highestRate.toStringMax4Decimals
    }

    var formattedLowestRate: String {
        lowestRate.toStringMax4Decimals
    }

    var formattedAverageRate: String {
        averageRate.toStringMax4Decimals
    }

    var volatilityLevel: VolatilityLevel? {
        volatility.map(VolatilityLevel.init(annualizedPercent:))
    }

    var formattedVolatility: String {
        volatilityLevel?.displayName ?? "N/A"
    }

    // MARK: - Chart Configuration

    var chartYDomain: ClosedRange<Double> {
        chartStatistics.chartYDomain
    }
}
