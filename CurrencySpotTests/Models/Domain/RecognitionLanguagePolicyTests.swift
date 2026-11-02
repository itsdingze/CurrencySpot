import Foundation
import Testing
@testable import CurrencySpot

@Suite("RecognitionLanguagePolicy")
struct RecognitionLanguagePolicyTests {
    private let visionLanguages = languages(
        "en-US", "fr-FR", "it-IT", "de-DE", "es-ES", "pt-BR", "zh-Hans", "zh-Hant", "yue-Hans", "yue-Hant",
        "ko-KR", "ja-JP", "ru-RU", "uk-UA", "th-TH", "vi-VT", "ar-SA", "ars-SA", "tr-TR", "id-ID", "cs-CZ",
        "da-DK", "nl-NL", "no-NO", "nn-NO", "nb-NO", "ms-MY", "pl-PL", "ro-RO", "sv-SE", "fi-FI", "hi-IN", "mr-IN"
    )

    private static func languages(_ identifiers: String...) -> [Locale.Language] {
        identifiers.map(Locale.Language.init(identifier:))
    }

    @Test("a yen menu is read as Japanese first, then English")
    func yenMenuReadsJapaneseFirst() {
        let policy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: [])

        let result = policy.languages(forMenuPricedIn: "JPY", supportedBy: visionLanguages)

        #expect(result == Self.languages("ja-JP", "en-US"))
    }

    @Test("a menu is read first in the language its currency's prices are written in", arguments: [
        ("CNY", "zh-Hans"), ("TWD", "zh-Hant"), ("HKD", "zh-Hant"), ("MOP", "zh-Hant"), ("KRW", "ko-KR"),
        ("THB", "th-TH"), ("VND", "vi-VT"), ("RUB", "ru-RU"), ("BYN", "ru-RU"), ("UAH", "uk-UA"), ("INR", "hi-IN"),
        ("TRY", "tr-TR"), ("IDR", "id-ID"), ("MYR", "ms-MY"), ("CZK", "cs-CZ"), ("PLN", "pl-PL"), ("RON", "ro-RO"),
        ("AED", "ar-SA"), ("SAR", "ar-SA"), ("QAR", "ar-SA"), ("KWD", "ar-SA"), ("BHD", "ar-SA"), ("OMR", "ar-SA"),
        ("EGP", "ar-SA"), ("BRL", "pt-BR"), ("MXN", "es-ES"), ("CHF", "de-DE"), ("DKK", "da-DK"), ("SEK", "sv-SE"),
        ("NOK", "nb-NO"),
    ] as [(CurrencyCode, String)])
    func menuLanguageLeads(currency: CurrencyCode, menuLanguage: String) {
        let policy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: [])

        let result = policy.languages(forMenuPricedIn: currency, supportedBy: visionLanguages)

        #expect(result == Self.languages(menuLanguage, "en-US"))
    }

    @Test("the reader's own languages come after the menu language and before English")
    func preferredLanguagesFollowTheMenuLanguage() {
        let policy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: ["fr-FR", "ko-KR"])

        let result = policy.languages(forMenuPricedIn: "JPY", supportedBy: visionLanguages)

        #expect(result == Self.languages("ja-JP", "fr-FR", "ko-KR", "en-US"))
    }

    @Test("a language the reader also prefers is listed once, in its first place")
    func repeatedLanguagesAreListedOnce() {
        let policy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: ["en-US", "ja-JP", "ko-KR"])

        let result = policy.languages(forMenuPricedIn: "JPY", supportedBy: visionLanguages)

        #expect(result == Self.languages("ja-JP", "en-US", "ko-KR"))
    }

    @Test("languages this system cannot read are left out")
    func unsupportedLanguagesAreLeftOut() {
        let policy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: ["hu-HU", "fr-FR"])
        let withoutHindi = visionLanguages.filter { $0 != Locale.Language(identifier: "hi-IN") }

        let result = policy.languages(forMenuPricedIn: "INR", supportedBy: withoutHindi)

        #expect(result == Self.languages("fr-FR", "en-US"))
    }

    @Test("a regional preference is read with the supported variant of its language and script", arguments: [
        ("zh-HK", "zh-Hant"), ("zh-TW", "zh-Hant"), ("zh-Hans-US", "zh-Hans"), ("zh", "zh-Hans"),
        ("de-AT", "de-DE"), ("pt-PT", "pt-BR"), ("es-MX", "es-ES"), ("ko", "ko-KR"),
    ])
    func regionalPreferenceUsesSupportedVariant(preferred: String, supported: String) {
        let policy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: [preferred])

        let result = policy.languages(forMenuPricedIn: "JPY", supportedBy: visionLanguages)

        #expect(result == Self.languages("ja-JP", supported, "en-US"))
    }

    @Test("a Latin-script menu is read as English first, ahead of the reader's own script", arguments: [
        "USD", "EUR", "GBP", "AUD", "CAD", "NZD", "SGD", "PHP", "ZAR", "HUF", "ISK",
    ] as [CurrencyCode])
    func latinScriptMenuReadsEnglishFirst(currency: CurrencyCode) {
        let policy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: ["ko-KR"])

        let result = policy.languages(forMenuPricedIn: currency, supportedBy: visionLanguages)

        #expect(result == Self.languages("en-US", "ko-KR"))
    }

    @Test("a regional variant of English is not listed beside English")
    func regionalEnglishMergesWithEnglish() {
        let policy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: ["en-GB", "ja-JP"])

        let result = policy.languages(forMenuPricedIn: "KRW", supportedBy: visionLanguages)

        #expect(result == Self.languages("ko-KR", "en-US", "ja-JP"))
    }
}
