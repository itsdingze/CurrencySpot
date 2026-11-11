@testable import CurrencySpot
import Foundation
import Testing

@Suite("App language localization")
struct AppLanguageLocalizationTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let shared: UserDefaults
    private let system = Locale(identifier: "en_GB")

    init() throws {
        shared = try isolatedDefaults.make()
    }

    @Test("a language chosen in the app replaces the system language and keeps the system region")
    func chosenLanguageKeepsSystemRegion() {
        shared.set("de", forKey: UserDefaultsKeys.appLanguage)

        let locale = Locale.appLanguage(in: shared, system: system)

        #expect(locale.language.languageCode == "de")
        #expect(locale.region == "GB")
    }

    @Test("with the language picker on System, the system locale is used unchanged")
    func systemLanguageUsesSystemLocale() {
        #expect(Locale.appLanguage(in: shared, system: system) == system)
    }

    @Test("a string resolves in the chosen language", arguments: [
        ("de", "Aktualisiert: 9:41"),
        ("ja", "更新: 9:41"),
        ("en", "Updated 9:41"),
    ])
    func stringResolvesInChosenLanguage(language: String, expected: String) {
        shared.set(language, forKey: UserDefaultsKeys.appLanguage)

        let text = String(localized: .widgetHeaderUpdated(date: "9:41"), in: .appLanguage(in: shared, system: system))

        #expect(text == expected)
    }

    @Test("with the language picker on System, a string resolves in the system language")
    func systemLanguageResolvesSystemStrings() {
        let text = String(localized: .widgetPairRateSamePair, in: .appLanguage(in: shared))

        #expect(text == String(localized: .widgetPairRateSamePair))
    }
}
