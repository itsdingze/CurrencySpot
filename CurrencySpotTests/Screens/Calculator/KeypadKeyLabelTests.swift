@testable import CurrencySpot
import Foundation
import Testing

@Suite("Keypad key VoiceOver labels")
struct KeypadKeyLabelTests {
    @Test(
        "the decimal key is named after the separator it shows, whatever the app language",
        arguments: [
            ("en_US", "Decimal point"),
            ("de_DE", "Decimal comma"),
            ("de_CH", "Decimal point"),
            ("es_AR", "Decimal comma"),
            ("es_MX", "Decimal point"),
        ]
    )
    func decimalKeyFollowsSeparator(region: String, label: String) {
        let locale = Locale(identifier: region)

        let resource = KeypadKey.Role.decimalPoint.accessibilityLabel(in: .calculator, locale: locale)

        #expect(String(localized: resource) == label)
    }
}
