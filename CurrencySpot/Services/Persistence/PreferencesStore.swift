import Foundation
import Observation

// MARK: - PreferencesStore

protocol PreferencesStore: AnyObject {
    var accentColor: AccentColorOption { get set }
    var appearanceMode: AppearanceMode { get set }
    var defaultBaseCurrency: CurrencyCode { get set }
    var defaultTargetCurrency: CurrencyCode { get set }
    var hasSeenOnboarding: Bool { get set }
    var hasSeenChartOnboarding: Bool { get set }
}

// MARK: - PreferenceDefaults

enum PreferenceDefaults {
    static let accentColor: AccentColorOption = .cyan
    static let appearanceMode: AppearanceMode = .system
    static let baseCurrency = CurrencyCode.usd
    static let targetCurrency = CurrencyCode.eur
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

    var hasSeenOnboarding: Bool {
        didSet { userDefaults.set(hasSeenOnboarding, forKey: UserDefaultsKeys.hasSeenOnboarding) }
    }

    var hasSeenChartOnboarding: Bool {
        didSet { userDefaults.set(hasSeenChartOnboarding, forKey: UserDefaultsKeys.hasSeenChartOnboarding) }
    }

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults

        accentColor = userDefaults.string(forKey: UserDefaultsKeys.accentColor)
            .flatMap { AccentColorOption(rawValue: $0) } ?? PreferenceDefaults.accentColor

        appearanceMode = userDefaults.string(forKey: UserDefaultsKeys.appearanceMode)
            .flatMap { AppearanceMode(rawValue: $0) } ?? PreferenceDefaults.appearanceMode

        defaultBaseCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultBaseCurrency)
            .flatMap { CurrencyCode($0) } ?? PreferenceDefaults.baseCurrency
        defaultTargetCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultTargetCurrency)
            .flatMap { CurrencyCode($0) } ?? PreferenceDefaults.targetCurrency
        hasSeenOnboarding = userDefaults.bool(forKey: UserDefaultsKeys.hasSeenOnboarding)
        hasSeenChartOnboarding = userDefaults.bool(forKey: UserDefaultsKeys.hasSeenChartOnboarding)
    }
}
