import Foundation

extension UserDefaults {
    nonisolated static var appGroup: UserDefaults {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String)
            .flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }
}
