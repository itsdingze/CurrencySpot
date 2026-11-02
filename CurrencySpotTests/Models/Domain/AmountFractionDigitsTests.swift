import Foundation
import Testing
@testable import CurrencySpot

struct AmountFractionDigitsTests {
    @Test(arguments: [("1200", "JPY", 0), ("12", "USD", 2), ("12.5", "EUR", 2), ("3.499", "USD", 3), ("1.234", "KWD", 3), ("1.5", "KWD", 3)])
    func scannedAmountShowsItsCurrencysUsualDecimalsOrMore(amount: String, currency: CurrencyCode, digits: Int) throws {
        let value = try #require(Decimal(string: amount))

        #expect(AmountFractionDigits.showing(value, in: currency) == digits)
    }

    @Test(arguments: [("JPY", 0), ("KRW", 0), ("USD", 2), ("EUR", 2), ("KWD", 3)])
    func convertedAmountShowsItsCurrencysUsualDecimals(currency: CurrencyCode, digits: Int) {
        #expect(AmountFractionDigits.usual(for: currency) == digits)
    }
}
