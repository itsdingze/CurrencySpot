import Foundation
import Observation

@Observable
final class UserDefaultsAppLanguageStore: AppLanguageStore {
    private static let preferredLanguagesKey = "AppleLanguages"

    let availableLanguages: [AppLanguage]

    private let userDefaults: UserDefaults
    private var savedPreferences: [String]?

    init(userDefaults: UserDefaults, domainName: String, availableIdentifiers: [String]) {
        self.userDefaults = userDefaults
        availableLanguages = availableIdentifiers.map(AppLanguage.init(identifier:))
        savedPreferences = userDefaults.persistentDomain(forName: domainName)?[Self.preferredLanguagesKey] as? [String]
    }

    var selectedLanguage: AppLanguage {
        get {
            let preferences = savedPreferences
            let identifiers = availableLanguages.map(\.identifier)
            let resolved = Bundle.preferredLocalizations(from: identifiers, forPreferences: preferences).first
            return availableLanguages.first { $0.identifier == resolved } ?? AppLanguage(identifier: "en")
        }
        set {
            userDefaults.set([newValue.identifier], forKey: Self.preferredLanguagesKey)
            savedPreferences = [newValue.identifier]
        }
    }

    var followsSystemLanguage: Bool {
        savedPreferences == nil
    }

    func resetToSystem() {
        userDefaults.removeObject(forKey: Self.preferredLanguagesKey)
        savedPreferences = nil
    }
}
