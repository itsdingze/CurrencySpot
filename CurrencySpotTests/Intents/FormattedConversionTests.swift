@testable import CurrencySpot
import Foundation
import Testing

@Suite("FormattedConversion")
struct FormattedConversionTests {
    private let conversion = ConvertCurrencyUseCase.Conversion(
        amount: 100,
        from: "USD",
        to: "EUR",
        converted: 86.123,
        ratesDate: Date(timeIntervalSince1970: 1_800_000_000)
    )

    @Test("a Siri or Shortcuts result reads like the calculator history, two decimals and the code")
    func matchesCalculatorHistoryFormat() {
        let formatted = FormattedConversion(conversion, locale: Locale(identifier: "en_US"))

        #expect(formatted.amount == "100.00 USD")
        #expect(formatted.converted == "86.12 EUR")
    }

    @Test("the spoken answer and the last update line use the language they are formatted in", arguments: [
        ("de_DE", "100,00 USD sind 86,12 EUR", "Zuletzt aktualisiert: "),
        ("ja_JP", "100.00 USDは86.12 EURです", "最終更新: "),
    ])
    func answerFollowsLanguage(identifier: String, dialog: String, lastUpdatedPrefix: String) throws {
        let formatted = FormattedConversion(conversion, locale: Locale(identifier: identifier))

        #expect(formatted.dialog == dialog)
        let lastUpdated = try #require(formatted.lastUpdated)
        #expect(lastUpdated.hasPrefix(lastUpdatedPrefix))
    }

    @Test("a missing rate is reported in the language it is asked for")
    func failureFollowsLanguage() {
        let failure = ConvertCurrencyUseCase.Failure.noRate("XYZ")

        #expect(failure.message(in: Locale(identifier: "de_DE")) == "Für XYZ ist kein Wechselkurs verfügbar.")
        #expect(failure.message(in: Locale(identifier: "ja_JP")) == "XYZの為替レートはありません。")
    }
}
