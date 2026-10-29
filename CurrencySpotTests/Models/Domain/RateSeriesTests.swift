@testable import CurrencySpot
import Foundation
import Testing

@Suite("RateSeries")
struct RateSeriesTests {
    private let response = HistoricalRatesResponse(
        base: "USD",
        startDate: "2026-10-01",
        endDate: "2026-10-03",
        rates: [
            "2026-10-03": ["EUR": 0.88, "JPY": 150.0],
            "2026-10-01": ["EUR": 0.80, "JPY": 160.0],
            "2026-10-02": ["EUR": 0.84, "JPY": 155.0],
        ]
    )

    @Test("each currency's rates run from the oldest day to the newest, in the requested order")
    func seriesFollowDatesAndRequestedOrder() {
        let series = RateSeries.series(for: ["JPY", "EUR"], in: response)

        #expect(series.map(\.currency) == ["JPY", "EUR"])
        #expect(series.map(\.rates) == [[160.0, 155.0, 150.0], [0.80, 0.84, 0.88]])
    }

    @Test("the base currency against itself is one on every day")
    func baseCurrencyIsOne() {
        let series = RateSeries.series(for: ["USD"], in: response)

        #expect(series.map(\.rates) == [[1, 1, 1]])
    }

    @Test("the change runs from the first rate of the period to the latest")
    func changeSpansThePeriod() throws {
        let series = RateSeries(currency: "EUR", rates: [0.80, 0.70, 0.88])

        #expect(series.latestRate == 0.88)
        #expect(abs(try #require(series.percentChange) - 10) < 0.000_001)
        #expect(series.direction == .up)
    }

    @Test("the average is the mean of every rate in the period")
    func averageIsTheMean() throws {
        let series = RateSeries(currency: "EUR", rates: [0.80, 0.70, 0.90])

        #expect(abs(try #require(series.averageRate) - 0.80) < 0.000_001)
        #expect(RateSeries(currency: "EUR", rates: []).averageRate == nil)
    }

    @Test("a currency the response lacks has no rate and no change")
    func missingCurrencyHasNoChange() {
        let series = RateSeries.series(for: ["GBP"], in: response)

        #expect(series.first?.latestRate == nil)
        #expect(series.first?.percentChange == nil)
        #expect(series.first?.direction == nil)
    }
}
