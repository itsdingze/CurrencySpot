import Foundation

nonisolated struct DateRange: Hashable, Sendable {
    let start: Date
    let end: Date

    private init(uncheckedStart start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    static func make(start: Date, end: Date) throws -> DateRange {
        guard start <= end else {
            throw AppError.dateCalculationError("Inverted date range: \(start) to \(end)")
        }
        return DateRange(uncheckedStart: start, end: end)
    }

    static func spanning(_ first: Date, _ second: Date) -> DateRange {
        first <= second
            ? DateRange(uncheckedStart: first, end: second)
            : DateRange(uncheckedStart: second, end: first)
    }
}
