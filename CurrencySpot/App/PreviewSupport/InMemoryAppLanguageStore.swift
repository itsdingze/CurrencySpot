#if DEBUG

    import Foundation

    final class InMemoryAppLanguageStore: AppLanguageStore {
        let availableLanguages: [AppLanguage]

        private let systemLanguage: AppLanguage
        private var savedLanguage: AppLanguage?

        init(availableIdentifiers: [String] = ["en", "ko", "zh-Hans", "zh-Hant"], systemIdentifier: String = "en") {
            availableLanguages = availableIdentifiers.map(AppLanguage.init(identifier:))
            systemLanguage = AppLanguage(identifier: systemIdentifier)
        }

        var selectedLanguage: AppLanguage {
            get { savedLanguage ?? systemLanguage }
            set { savedLanguage = newValue }
        }

        func resetToSystem() {
            savedLanguage = nil
        }
    }

#endif
