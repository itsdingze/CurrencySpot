@testable import CurrencySpot
import Foundation
import Testing

@Suite("UserDefaultsAppLanguageStore Tests")
struct AppLanguageStoreTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let defaults: UserDefaults
    private let domainName: String

    init() throws {
        (defaults, domainName) = try isolatedDefaults.makeSuite()
    }

    private func makeStore() -> UserDefaultsAppLanguageStore {
        UserDefaultsAppLanguageStore(
            userDefaults: defaults,
            domainName: domainName,
            availableIdentifiers: ["en", "zh-Hans", "de"]
        )
    }

    @Test("a language saved for the app is the selected language")
    func savedChoiceIsSelected() {
        defaults.set(["zh-Hans-CN", "en-US"], forKey: "AppleLanguages")

        #expect(makeStore().selectedLanguage == AppLanguage(identifier: "zh-Hans"))
    }

    @Test("choosing a language saves it for the next launch")
    func choosingSavesForNextLaunch() {
        makeStore().selectedLanguage = AppLanguage(identifier: "de")

        #expect(makeStore().selectedLanguage == AppLanguage(identifier: "de"))
    }

    @Test("the store follows the system language until a language is chosen, and again after a reset")
    func followsSystemUntilChosen() {
        let store = makeStore()
        #expect(store.followsSystemLanguage)

        store.selectedLanguage = AppLanguage(identifier: "de")
        #expect(makeStore().followsSystemLanguage == false)

        store.resetToSystem()
        #expect(makeStore().followsSystemLanguage)
    }

    @Test("resetting removes the app language override")
    func resetRemovesSavedChoice() {
        let store = makeStore()
        store.selectedLanguage = AppLanguage(identifier: "de")

        store.resetToSystem()

        #expect(defaults.persistentDomain(forName: domainName)?["AppleLanguages"] == nil)
    }
}
