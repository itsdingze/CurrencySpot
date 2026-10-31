@testable import CurrencySpot
import Foundation
import Testing

@Suite("FormattedConversion")
struct FormattedConversionTests {
    @Test("a Siri or Shortcuts result reads like the calculator history, two decimals and the code")
    func matchesCalculatorHistoryFormat() {
        let conversion = ConvertCurrencyUseCase.Conversion(amount: 100, from: "USD", to: "EUR", converted: 86.123, ratesDate: nil)

        let formatted = FormattedConversion(conversion, locale: Locale(identifier: "en_US"))

        #expect(formatted.amount == "100.00 USD")
        #expect(formatted.converted == "86.12 EUR")
    }
}
