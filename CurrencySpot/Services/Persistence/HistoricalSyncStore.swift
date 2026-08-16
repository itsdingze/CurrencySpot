import Foundation

protocol HistoricalSyncStore: AnyObject {
    var from: Date? { get }
    var through: Date? { get }
    var checkedAt: Date? { get }

    func record(from: Date, through: Date, at now: Date)

    func reset()
}

final class UserDefaultsHistoricalSyncStore: HistoricalSyncStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var from: Date? { defaults.object(forKey: UserDefaultsKeys.historicalSyncFrom) as? Date }
    var through: Date? { defaults.object(forKey: UserDefaultsKeys.historicalSyncThrough) as? Date }
    var checkedAt: Date? { defaults.object(forKey: UserDefaultsKeys.historicalSyncCheckedAt) as? Date }

    func record(from newFrom: Date, through newThrough: Date, at now: Date) {
        if let from, let through, !Self.overlapsOrAdjacent(from: from, through: through, newFrom: newFrom, newThrough: newThrough) {
            guard newThrough > through else { return }
            defaults.set(newFrom, forKey: UserDefaultsKeys.historicalSyncFrom)
            defaults.set(newThrough, forKey: UserDefaultsKeys.historicalSyncThrough)
            defaults.set(now, forKey: UserDefaultsKeys.historicalSyncCheckedAt)
            return
        }

        defaults.set(min(from ?? newFrom, newFrom), forKey: UserDefaultsKeys.historicalSyncFrom)
        defaults.set(max(through ?? newThrough, newThrough), forKey: UserDefaultsKeys.historicalSyncThrough)
        defaults.set(now, forKey: UserDefaultsKeys.historicalSyncCheckedAt)
    }

    private static func overlapsOrAdjacent(from: Date, through: Date, newFrom: Date, newThrough: Date) -> Bool {
        let calendar = TimeZoneManager.cetCalendar
        guard let throughPlusDay = calendar.date(byAdding: .day, value: 1, to: through),
              let fromMinusDay = calendar.date(byAdding: .day, value: -1, to: from)
        else {
            return true
        }
        return newFrom <= throughPlusDay && newThrough >= fromMinusDay
    }

    func reset() {
        defaults.removeObject(forKey: UserDefaultsKeys.historicalSyncFrom)
        defaults.removeObject(forKey: UserDefaultsKeys.historicalSyncThrough)
        defaults.removeObject(forKey: UserDefaultsKeys.historicalSyncCheckedAt)
    }
}
