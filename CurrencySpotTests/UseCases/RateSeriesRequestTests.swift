@testable import CurrencySpot
import Testing

@Suite("RateSeriesRequest")
struct RateSeriesRequestTests {
    @Test("a list keeps each picked currency once, skips the base, and stops at the row limit")
    func listDropsDuplicatesAndBase() {
        let request = RateSeriesRequest.list(
            base: "USD",
            currencies: ["EUR", "USD", "EUR", "JPY", "GBP", "CHF"],
            period: .oneMonth,
            limit: 3
        )

        #expect(request.currencies == ["EUR", "JPY", "GBP"])
    }
}
