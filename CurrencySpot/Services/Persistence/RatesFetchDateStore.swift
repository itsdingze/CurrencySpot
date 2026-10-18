import Foundation

protocol RatesFetchDateStore: AnyObject {
    var lastFetchDate: Date? { get set }
}

final class UserDefaultsRatesFetchDateStore: RatesFetchDateStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var lastFetchDate: Date? {
        get { defaults.object(forKey: UserDefaultsKeys.lastFetchDate) as? Date }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.lastFetchDate) }
    }
}
