@testable import CurrencySpot
import Foundation
import Testing

@Suite("DateRange invariant")
struct DateRangeTests {
    private let earlier = Date(timeIntervalSince1970: 1_000_000)
    private let later = Date(timeIntervalSince1970: 2_000_000)

    @Test("make accepts an ordered pair unchanged")
    func makeAcceptsOrderedBounds() throws {
        let range = try DateRange.make(start: earlier, end: later)

        #expect(range.start == earlier)
        #expect(range.end == later)
    }

    @Test("make accepts a single-instant range")
    func makeAcceptsEmptyRange() throws {
        let range = try DateRange.make(start: earlier, end: earlier)

        #expect(range.start == range.end)
    }

    @Test("make rejects an inverted pair instead of yielding an empty result set")
    func makeRejectsInvertedBounds() {
        #expect(throws: AppError.self) {
            _ = try DateRange.make(start: later, end: earlier)
        }
    }

    @Test("spanning orders whichever way the bounds arrive")
    func spanningOrdersBounds() {
        #expect(DateRange.spanning(later, earlier).start == earlier)
        #expect(DateRange.spanning(later, earlier).end == later)
        #expect(DateRange.spanning(earlier, later).start == earlier)
    }
}
