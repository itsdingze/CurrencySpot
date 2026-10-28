@testable import CurrencySpot
import Foundation
import Synchronization

final class AdjustableDateProvider: DateProvider {
    private let current: Mutex<Date>

    init(_ start: Date) {
        current = Mutex(start)
    }

    func now() -> Date {
        current.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        current.withLock { $0.addTimeInterval(interval) }
    }
}
