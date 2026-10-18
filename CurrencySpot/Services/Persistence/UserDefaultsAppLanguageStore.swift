import Foundation

final class UserDefaultsAppLanguageStore: AppLanguageStore {
    private static let preferredLanguagesKey = "AppleLanguages"

    let availableLanguages: [AppLanguage]

    private let userDefaults: UserDefaults
    private let domainName: String

    init(userDefaults: UserDefaults, domainName: String, availableIdentifiers: [String]) {
        self.userDefaults = userDefaults
        self.domainName = domainName
        availableLanguages = availableIdentifiers.map(AppLanguage.init(identifier:))
    }

    private var savedPreferences: [String]? {
        userDefaults.persistentDomain(forName: domainName)?[Self.preferredLanguagesKey] as? [String]
    }

    var selectedLanguage: AppLanguage {
        get {
            let preferences = savedPreferences
            let identifiers = availableLanguages.map(\.identifier)
            let resolved = Bundle.preferredLocalizations(from: identifiers, forPreferences: preferences).first
            return availableLanguages.first { $0.identifier == resolved } ?? AppLanguage(identifier: "en")
        }
        set { userDefaults.set([newValue.identifier], forKey: Self.preferredLanguagesKey) }
    }

    func resetToSystem() {
        userDefaults.removeObject(forKey: Self.preferredLanguagesKey)
    }
}
