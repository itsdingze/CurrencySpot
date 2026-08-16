import Foundation
import IdentifiedCollections
import Observation

// MARK: - PreferencesStore

protocol PreferencesStore: AnyObject {
    var accentColor: AccentColorOption { get set }
    var appearanceMode: AppearanceMode { get set }
    var defaultBaseCurrency: CurrencyCode { get set }
    var defaultTargetCurrency: CurrencyCode { get set }
    var favoriteCurrencies: CurrencyCodeList { get }
    var hasSeenOnboarding: Bool { get set }
    var hasSeenChartOnboarding: Bool { get set }

    @discardableResult
    func addFavorite(_ code: CurrencyCode) -> Bool

    @discardableResult
    func removeFavorite(_ code: CurrencyCode) -> Bool

    func moveFavorites(from: IndexSet, to: Int)

    func resetToDefaults()
}

// MARK: - PreferenceDefaults

enum PreferenceDefaults {
    static let accentColor: AccentColorOption = .cyan
    static let appearanceMode: AppearanceMode = .system
    static let baseCurrency = CurrencyCode.usd
    static let targetCurrency = CurrencyCode.eur
    static let favoriteCurrencies = CurrencyDefaults.favoriteCurrencies
    static let hasSeenOnboarding = false
    static let hasSeenChartOnboarding = false
}

// MARK: - UserDefaultsPreferencesStore

@Observable
final class UserDefaultsPreferencesStore: PreferencesStore {
    var accentColor: AccentColorOption {
        didSet { userDefaults.set(accentColor.rawValue, forKey: UserDefaultsKeys.accentColor) }
    }

    var appearanceMode: AppearanceMode {
        didSet { userDefaults.set(appearanceMode.rawValue, forKey: UserDefaultsKeys.appearanceMode) }
    }

    var defaultBaseCurrency: CurrencyCode {
        didSet { userDefaults.set(defaultBaseCurrency.rawValue, forKey: UserDefaultsKeys.defaultBaseCurrency) }
    }

    var defaultTargetCurrency: CurrencyCode {
        didSet { userDefaults.set(defaultTargetCurrency.rawValue, forKey: UserDefaultsKeys.defaultTargetCurrency) }
    }

    private(set) var favoriteCurrencies: CurrencyCodeList {
        didSet { userDefaults.set(favoriteCurrencies.map(\.rawValue), forKey: UserDefaultsKeys.favoriteCurrencies) }
    }

    var hasSeenOnboarding: Bool {
        didSet { userDefaults.set(hasSeenOnboarding, forKey: UserDefaultsKeys.hasSeenOnboarding) }
    }

    var hasSeenChartOnboarding: Bool {
        didSet { userDefaults.set(hasSeenChartOnboarding, forKey: UserDefaultsKeys.hasSeenChartOnboarding) }
    }

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        accentColor = userDefaults.string(forKey: UserDefaultsKeys.accentColor)
            .flatMap { AccentColorOption(rawValue: $0) } ?? PreferenceDefaults.accentColor

        appearanceMode = userDefaults.string(forKey: UserDefaultsKeys.appearanceMode)
            .flatMap { AppearanceMode(rawValue: $0) } ?? PreferenceDefaults.appearanceMode

        defaultBaseCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultBaseCurrency)
            .flatMap { CurrencyCode($0) } ?? PreferenceDefaults.baseCurrency
        defaultTargetCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultTargetCurrency)
            .flatMap { CurrencyCode($0) } ?? PreferenceDefaults.targetCurrency
        favoriteCurrencies = .deduplicating(
            userDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies)
                .map { $0.compactMap { CurrencyCode($0) } } ?? PreferenceDefaults.favoriteCurrencies
        )
        hasSeenOnboarding = userDefaults.bool(forKey: UserDefaultsKeys.hasSeenOnboarding)
        hasSeenChartOnboarding = userDefaults.bool(forKey: UserDefaultsKeys.hasSeenChartOnboarding)
    }

    // MARK: - Favorites

    @discardableResult
    func addFavorite(_ code: CurrencyCode) -> Bool {
        let (inserted, _) = favoriteCurrencies.append(code)
        return inserted
    }

    @discardableResult
    func removeFavorite(_ code: CurrencyCode) -> Bool {
        favoriteCurrencies.remove(id: code) != nil
    }

    func moveFavorites(from: IndexSet, to: Int) {
        favoriteCurrencies.move(fromOffsets: from, toOffset: to)
    }

    // MARK: - Reset

    func resetToDefaults() {
        accentColor = PreferenceDefaults.accentColor
        appearanceMode = PreferenceDefaults.appearanceMode
        defaultBaseCurrency = PreferenceDefaults.baseCurrency
        defaultTargetCurrency = PreferenceDefaults.targetCurrency
        favoriteCurrencies = .deduplicating(PreferenceDefaults.favoriteCurrencies)
        hasSeenOnboarding = PreferenceDefaults.hasSeenOnboarding
        hasSeenChartOnboarding = PreferenceDefaults.hasSeenChartOnboarding
    }
}
