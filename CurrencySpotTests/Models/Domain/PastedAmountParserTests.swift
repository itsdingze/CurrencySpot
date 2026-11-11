@testable import CurrencySpot
import Foundation
import Testing

@Suite("PastedAmountParser Tests")
struct PastedAmountParserTests {
    private let english = PastedAmountParser(locale: Locale(identifier: "en_US"))
    private let german = PastedAmountParser(locale: Locale(identifier: "de_DE"))

    @Test("either decimal convention, grouping and a surrounding symbol or code are read", arguments: [
        ("1,234.56", "1234.56"),
        ("1.234,56", "1234.56"),
        ("€ 12,50", "12.5"),
        ("12.5 USD", "12.5"),
        ("1 234,5", "1234.5"),
        ("1\u{00A0}234,56", "1234.56"),
        ("1\u{202F}234,56 €", "1234.56"),
        ("CHF 1'234.50", "1234.5"),
        ("1,234,567.89", "1234567.89"),
        ("₹1,23,456.00", "123456"),
        ("  42\n", "42"),
        ("$12.", "12"),
    ])
    func readsAmounts(text: String, expected: String) throws {
        #expect(english.amount(in: text) == Decimal(string: expected))
    }

    @Test("an amount is rounded to cents")
    func roundsToCents() {
        #expect(english.amount(in: "0.125") == Decimal(string: "0.13"))
        #expect(english.amount(in: "19.994") == Decimal(string: "19.99"))
    }

    @Test("a lone separator before three digits follows the current locale")
    func ambiguousSeparatorFollowsLocale() {
        #expect(english.amount(in: "1,234") == 1234)
        #expect(english.amount(in: "1.234") == Decimal(string: "1.23"))
        #expect(german.amount(in: "1.234") == 1234)
        #expect(german.amount(in: "1,234") == Decimal(string: "1.23"))
        #expect(english.amount(in: "0,125") == Decimal(string: "0.13"))
    }

    @Test("text without one usable positive number gives no amount", arguments: [
        "",
        "Lunch",
        "0",
        "0.004",
        "-5",
        "€ -12,50",
        ".5",
        "12 apples and 5 pears",
        "555-1234",
        "1.2.3",
        "12 50",
        "1,2345,678",
        "1.234.56,7.8",
    ])
    func rejectsUnusableText(text: String) {
        #expect(english.amount(in: text) == nil)
    }
}
