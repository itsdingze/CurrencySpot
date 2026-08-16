import Foundation

nonisolated protocol DateProvider: Sendable {
    func now() -> Date
}

nonisolated struct SystemDateProvider: DateProvider {
    func now() -> Date {
        Date()
    }
}
