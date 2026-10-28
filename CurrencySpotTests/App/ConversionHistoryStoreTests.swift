@testable import CurrencySpot
import Foundation
import Testing

@Suite("ConversionHistoryStore Tests")
struct ConversionHistoryStoreTests {
    private let isolatedDefaults = IsolatedDefaults()

    private func record(_ amount: Decimal, minutesAfterEpoch minutes: Double = 0) -> ConversionRecord {
        ConversionRecord(
            id: UUID(),
            calculation: nil,
            amount: amount,
            base: "USD",
            target: "EUR",
            converted: amount,
            date: Date(timeIntervalSince1970: minutes * 60)
        )
    }

    @Test("records survive a relaunch, newest first")
    func recordsPersistNewestFirst() throws {
        let defaults = try isolatedDefaults.make()
        let store = ConversionHistoryStore(defaults: defaults)
        let older = record(1, minutesAfterEpoch: 1)
        let newer = record(2, minutesAfterEpoch: 2)

        store.add(older)
        store.add(newer)

        #expect(ConversionHistoryStore(defaults: defaults).records == [newer, older])
    }

    @Test("a calculation survives a relaunch with its steps")
    func calculationPersists() throws {
        let defaults = try isolatedDefaults.make()
        var calculation = CalculatorExpression()
        [.digit(8), .operation(.multiply), .digit(3)].forEach { calculation.apply($0) }
        let saved = ConversionRecord(
            id: UUID(),
            calculation: calculation,
            amount: 24,
            base: "USD",
            target: "EUR",
            converted: 21.48,
            date: .now
        )

        ConversionHistoryStore(defaults: defaults).add(saved)

        #expect(ConversionHistoryStore(defaults: defaults).records == [saved])
    }

    @Test("only the newest hundred records are kept")
    func keepsNewestHundred() throws {
        let store = ConversionHistoryStore(defaults: try isolatedDefaults.make())
        let oldest = record(0)
        store.add(oldest)
        for minute in 1 ... 100 { store.add(record(Decimal(minute), minutesAfterEpoch: Double(minute))) }

        #expect(store.records.count == 100)
        #expect(store.records.contains(oldest) == false)
        #expect(store.records.first?.amount == 100)
    }

    @Test("a damaged entry is skipped on relaunch and the readable ones survive")
    func damagedEntryIsSkipped() throws {
        let defaults = try isolatedDefaults.make()
        let store = ConversionHistoryStore(defaults: defaults)
        let kept = record(7)
        store.add(kept)
        let saved = try #require(defaults.data(forKey: UserDefaultsKeys.conversionHistory))
        var entries = try #require(try JSONSerialization.jsonObject(with: saved) as? [[String: Any]])
        var damaged = entries[0]
        damaged["calculation"] = ["operands": [String](), "operators": [String](), "isSettled": true]
        entries.append(damaged)
        defaults.set(try JSONSerialization.data(withJSONObject: entries), forKey: UserDefaultsKeys.conversionHistory)

        #expect(ConversionHistoryStore(defaults: defaults).records == [kept])
    }

    @Test("deleting removes the chosen records, and clearing removes all, across a relaunch")
    func deleteAndClear() throws {
        let defaults = try isolatedDefaults.make()
        let store = ConversionHistoryStore(defaults: defaults)
        let first = record(1)
        let second = record(2)
        let third = record(3)
        [first, second, third].forEach(store.add)

        store.delete(ids: [first.id, third.id])
        #expect(ConversionHistoryStore(defaults: defaults).records == [second])

        store.clear()
        #expect(ConversionHistoryStore(defaults: defaults).records.isEmpty)
    }
}
