@testable import CurrencySpot
import Foundation
import Testing

@Suite("ConversionHistoryViewModel Tests")
struct ConversionHistoryViewModelTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let store: ConversionHistoryStore
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    init() throws {
        store = ConversionHistoryStore(defaults: try isolatedDefaults.make())
    }

    private func record(
        at isoDate: String = "2026-10-27T08:00:00Z",
        calculation: CalculatorExpression? = nil,
        amount: Decimal = 1,
        converted: Decimal = 1
    ) throws -> ConversionRecord {
        ConversionRecord(
            id: UUID(),
            calculation: calculation,
            amount: amount,
            base: "USD",
            target: "EUR",
            converted: converted,
            date: try #require(ISO8601DateFormatter().date(from: isoDate))
        )
    }

    private func makeViewModel(restored: @escaping (ConversionRecord) -> Void = { _ in }) -> ConversionHistoryViewModel {
        ConversionHistoryViewModel(store: store, calendar: calendar, locale: Locale(identifier: "en_US"), restore: restored)
    }

    @Test("records are grouped by day, newest day first and newest record first")
    func groupsByDay() throws {
        let morning = try record(at: "2026-10-27T08:00:00Z")
        let evening = try record(at: "2026-10-27T20:00:00Z")
        let nextDay = try record(at: "2026-10-28T09:00:00Z")
        [morning, evening, nextDay].forEach(store.add)

        let sections = makeViewModel().sections

        #expect(sections.map { $0.records } == [[nextDay], [evening, morning]])
    }

    @Test("a past day's section is titled by its date in the locale")
    func sectionTitle() throws {
        store.add(try record(at: "2025-03-14T12:00:00Z"))
        let viewModel = makeViewModel()

        let section = try #require(viewModel.sections.first)

        #expect(viewModel.title(for: section) == "Mar 14, 2025")
    }

    @Test("a calculation reads as its steps equal to the amount in the From currency")
    func calculationSummary() throws {
        var calculation = CalculatorExpression()
        [.digit(1), .digit(2), .digit(5), .digit(0), .operation(.add), .digit(8)].forEach { calculation.apply($0) }
        let entry = try record(calculation: calculation, amount: 1258, converted: 1125.67)

        let viewModel = makeViewModel()

        #expect(viewModel.summary(for: entry) == "1,250 + 8 = 1,258.00 USD")
        #expect(viewModel.convertedAmount(for: entry) == "1,125.67 EUR")
    }

    @Test("a typed amount reads as the amount in the From currency alone")
    func amountSummary() throws {
        let entry = try record(amount: 100, converted: 89.48)

        let viewModel = makeViewModel()

        #expect(viewModel.summary(for: entry) == "100.00 USD")
        #expect(viewModel.convertedAmount(for: entry) == "89.48 EUR")
    }

    @Test("choosing a record hands it back to the converter")
    func choosingRestores() throws {
        let chosen = try record()
        store.add(chosen)
        var restored: ConversionRecord?

        makeViewModel { restored = $0 }.choose(chosen)

        #expect(restored == chosen)
    }

    @Test("deleting removes the chosen records, and clearing empties the history")
    func deleteAndClear() throws {
        let first = try record(at: "2026-10-27T08:00:00Z")
        let second = try record(at: "2026-10-27T09:00:00Z")
        [first, second].forEach(store.add)
        let viewModel = makeViewModel()

        viewModel.delete(ids: [first.id])
        #expect(viewModel.sections.flatMap(\.records) == [second])

        viewModel.clearAll()
        #expect(viewModel.sections.isEmpty)
    }
}
