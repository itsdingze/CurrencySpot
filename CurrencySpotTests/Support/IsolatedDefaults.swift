import Foundation
import Testing

nonisolated final class IsolatedDefaults {
    private var suiteNames: [String] = []

    func make() throws -> UserDefaults {
        let suiteName = "CurrencySpotTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        suiteNames.append(suiteName)
        return defaults
    }

    deinit {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
    }
}
