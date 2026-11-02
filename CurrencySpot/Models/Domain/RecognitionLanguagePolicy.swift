import Foundation

nonisolated struct RecognitionLanguagePolicy: Sendable {
    private static let english = Locale.Language(identifier: "en-US")

    private static let menuLanguageIdentifiers: [String: String] = [
        "JPY": "ja-JP",
        "CNY": "zh-Hans",
        "TWD": "zh-Hant", "HKD": "zh-Hant", "MOP": "zh-Hant",
        "KRW": "ko-KR",
        "THB": "th-TH",
        "VND": "vi-VT",
        "RUB": "ru-RU", "BYN": "ru-RU",
        "UAH": "uk-UA",
        "INR": "hi-IN",
        "TRY": "tr-TR",
        "IDR": "id-ID",
        "MYR": "ms-MY",
        "CZK": "cs-CZ",
        "PLN": "pl-PL",
        "RON": "ro-RO",
        "AED": "ar-SA", "SAR": "ar-SA", "QAR": "ar-SA", "KWD": "ar-SA", "BHD": "ar-SA", "OMR": "ar-SA", "EGP": "ar-SA",
        "BRL": "pt-BR",
        "MXN": "es-ES",
        "CHF": "de-DE",
        "DKK": "da-DK",
        "SEK": "sv-SE",
        "NOK": "nb-NO",
        "USD": "en-US", "EUR": "en-US", "GBP": "en-US", "AUD": "en-US", "CAD": "en-US", "NZD": "en-US",
        "SGD": "en-US", "PHP": "en-US", "ZAR": "en-US", "HUF": "en-US", "ISK": "en-US",
    ]

    private let preferredLanguages: [Locale.Language]

    init(preferredLanguageIdentifiers: [String]) {
        preferredLanguages = preferredLanguageIdentifiers.map(Locale.Language.init(identifier:))
    }

    func languages(forMenuPricedIn currency: CurrencyCode, supportedBy supportedLanguages: [Locale.Language]) -> [Locale.Language] {
        let menuLanguage = Self.menuLanguageIdentifiers[currency.rawValue].map(Locale.Language.init(identifier:))
        let requested = [menuLanguage].compactMap { $0 } + preferredLanguages + [Self.english]
        return requested
            .compactMap { Self.supportedVariant(of: $0, in: supportedLanguages) }
            .reduce(into: []) { chosen, language in
                if !chosen.contains(language) { chosen.append(language) }
            }
    }

    private static func supportedVariant(of language: Locale.Language, in supportedLanguages: [Locale.Language]) -> Locale.Language? {
        if supportedLanguages.contains(language) { return language }
        return supportedLanguages.first { $0.languageCode == language.languageCode && $0.script == language.script }
    }
}
