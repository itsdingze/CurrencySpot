@testable import CurrencySpot
import Foundation
import Testing

@Suite("RateTable Tests")
struct RateTableTests {
    private static let usdToEUR = 1.21
    private static let usdToGBP = 0.85
    private static let usdToJPY = 110.0

    private let table = RateTable([
        ExchangeRate(currencyCode: "EUR", rate: usdToEUR),
        ExchangeRate(currencyCode: "GBP", rate: usdToGBP),
        ExchangeRate(currencyCode: "JPY", rate: usdToJPY),
    ])

    // MARK: - USD base: rate is returned unchanged

    @Test("USD base returns the USD->target rate unchanged")
    func usdBaseReturnsRateUnchanged() {
        #expect(abs(table.crossRate(from: "USD", to: "EUR") - Self.usdToEUR) < 0.0001)
        #expect(abs(table.crossRate(from: "USD", to: "JPY") - Self.usdToJPY) < 0.0001)
    }

    @Test("USD is implicitly 1.0 even when the table has no USD entry")
    func usdImplicitWhenAbsent() {
        #expect(table.usdRate(for: "USD") == 1.0)
        #expect(table.crossRate(from: "EUR", to: "USD") == 1.0 / Self.usdToEUR)
    }

    // MARK: - Cross rates: Base->Target = (USD->Target) / (USD->Base)

    @Test("EUR base, GBP target divides USD->GBP by USD->EUR")
    func eurBaseGbpTarget() {
        #expect(abs(table.crossRate(from: "EUR", to: "GBP") - 0.7024793) < 0.0001)
    }

    @Test("GBP base, JPY target divides USD->JPY by USD->GBP")
    func gbpBaseJpyTarget() {
        #expect(abs(table.crossRate(from: "GBP", to: "JPY") - 129.41176) < 0.01)
    }

    @Test("Realistic EUR->GBP cross rate is below 1 and matches the hand computation")
    func realisticEurToGbp() {
        let table = RateTable([
            ExchangeRate(currencyCode: "EUR", rate: 1.08),
            ExchangeRate(currencyCode: "GBP", rate: 0.79),
        ])
        let result = table.crossRate(from: "EUR", to: "GBP")
        #expect(abs(result - 0.731481) < 0.0001)
        #expect(result < 1.0)
    }

    @Test("Same base and target is exactly 1.0")
    func sameCurrencyIsOne() {
        #expect(table.crossRate(from: "EUR", to: "EUR") == 1.0)
    }

    // MARK: - Fallback behavior (missing or degenerate base rates)

    @Test("An empty table treats every code as 1.0")
    func emptyTableFallsBack() {
        #expect(RateTable.empty.crossRate(from: "EUR", to: "GBP") == 1.0)
    }

    @Test("A base currency missing from the table behaves as 1.0")
    func missingBaseCurrencyFallsBack() {
        #expect(table.crossRate(from: "CAD", to: "JPY") == Self.usdToJPY)
    }

    @Test("A target currency missing from the table behaves as 1.0")
    func missingTargetCurrencyFallsBack() {
        #expect(abs(table.crossRate(from: "EUR", to: "CAD") - (1.0 / Self.usdToEUR)) < 0.0001)
    }

    @Test("Zero base rate falls back to the unconverted target rate instead of producing infinity")
    func zeroBaseRateFallsBack() {
        let table = RateTable([
            ExchangeRate(currencyCode: "EUR", rate: 0.0),
            ExchangeRate(currencyCode: "GBP", rate: 0.85),
        ])
        let result = table.crossRate(from: "EUR", to: "GBP")
        #expect(result == 0.85)
        #expect(result.isFinite)
    }

    @Test("Zero USD->target with non-USD base yields zero")
    func zeroTargetRateNonUsdBase() {
        let table = RateTable([
            ExchangeRate(currencyCode: "EUR", rate: Self.usdToEUR),
            ExchangeRate(currencyCode: "GBP", rate: 0.0),
        ])
        #expect(table.crossRate(from: "EUR", to: "GBP") == 0.0)
    }

    // MARK: - Historical-table construction

    @Test("A table built from historical points prefers those rates")
    func historicalPointsTable() {
        let historical = RateTable(points: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.5)])
        #expect(abs((3.0 / (historical.usdRate(for: "EUR") ?? 1.0)) - 2.0) < 0.0001)
    }

    // MARK: - Decimal conversion (scan path)

    @Test("Decimal conversion divides last and keeps exact results exact")
    func decimalConversionIsExact() {
        let table = RateTable([
            ExchangeRate(currencyCode: "JPY", rate: 150),
            ExchangeRate(currencyCode: "USD", rate: 1),
        ])
        #expect(table.convert(1200, from: "JPY", to: "USD") == 8)
    }

    @Test("Decimal conversion returns the amount unchanged for a zero base rate")
    func decimalConversionZeroBase() {
        let table = RateTable([
            ExchangeRate(currencyCode: "JPY", rate: 0),
            ExchangeRate(currencyCode: "USD", rate: 1),
        ])
        #expect(table.convert(1200, from: "JPY", to: "USD") == 1200)
    }

    // MARK: - Magnitude / precision

    @Test("Division with extreme magnitudes is exact and does not underflow to zero")
    func extremeMagnitudeDivision() {
        let table = RateTable([
            ExchangeRate(currencyCode: "BIG", rate: 1_000_000_000.0),
            ExchangeRate(currencyCode: "TNY", rate: 0.000_000_001),
        ])
        let result = table.crossRate(from: "BIG", to: "TNY")
        #expect(abs(result - 1e-18) < 1e-24)
        #expect(result > 0.0)
        #expect(result.isFinite)
    }
}
