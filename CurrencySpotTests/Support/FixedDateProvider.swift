@testable import CurrencySpot
import Foundation

struct FixedDateProvider: DateProvider {
    let fixedNow: Date

    init(_ fixedNow: Date) {
        self.fixedNow = fixedNow
    }

    func now() -> Date {
        fixedNow
    }
}
