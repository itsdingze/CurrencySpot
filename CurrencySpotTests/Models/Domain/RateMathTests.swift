@testable import CurrencySpot
import Testing

@Suite("RateMath Tests")
struct RateMathTests {
    @Test("the price change is the move from the week's first rate to the current one")
    func priceChangeMeasuresFromTheFirstRate() {
        let change = RateMath.priceChange(rate: 150, percentChange: 10)

        #expect(abs(change - 13.6364) < 0.0001)
    }

    @Test("a fall to zero reports no price change instead of an infinite one")
    func fallToZeroReportsNoChange() {
        #expect(RateMath.priceChange(rate: 150, percentChange: -100) == 0)
    }
}
