import Foundation

nonisolated struct AppLanguage: Hashable, Identifiable, Sendable {
    let identifier: String

    var id: String { identifier }

    var displayName: String {
        Locale(identifier: identifier).localizedString(forIdentifier: identifier) ?? identifier
    }
}
