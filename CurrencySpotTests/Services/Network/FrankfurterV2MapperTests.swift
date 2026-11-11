import Foundation
import Testing
@testable import CurrencySpot

@Suite("FrankfurterV2Mapper")
struct FrankfurterV2MapperTests {
    @Test("latest collapses the v2 array into the rates dictionary")
    func latestMapsRates() throws {
        let entries = [
            FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "EUR", rate: 0.86),
            FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "GBP", rate: 0.74),
        ]

        let response = try FrankfurterV2Mapper.latest(from: entries, base: "USD")

        #expect(response.base == "USD")
        #expect(response.rates["EUR"] == 0.86)
        #expect(response.rates["GBP"] == 0.74)
    }

    @Test("latest collapses mixed per-currency dates to the most recent")
    func latestUsesMaxDate() throws {
        let entries = [
            FrankfurterV2Rate(date: "2026-06-05", base: "USD", quote: "ALL", rate: 81.7),
            FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "EUR", rate: 0.86),
            FrankfurterV2Rate(date: "2026-06-06", base: "USD", quote: "BIF", rate: 2985.0),
        ]

        let response = try FrankfurterV2Mapper.latest(from: entries, base: "USD")

        #expect(response.date == "2026-06-07")
    }

    @Test("historical regroups the flat v2 array into per-date keyed rates")
    func historicalRegroupsByDate() throws {
        let entries = [
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "EUR", rate: 0.85),
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "GBP", rate: 0.74),
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "EUR", rate: 0.86),
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "GBP", rate: 0.75),
        ]

        let response = try FrankfurterV2Mapper.historical(from: entries, base: "USD", startingOn: "2026-01-02")

        #expect(response.base == "USD")
        #expect(response.startDate == "2026-01-02")
        #expect(response.endDate == "2026-01-03")
        #expect(response.rates["2026-01-02"]?["EUR"] == 0.85)
        #expect(response.rates["2026-01-03"]?["GBP"] == 0.75)
    }

    @Test("historical forward-fills a currency missing on a later date")
    func historicalForwardFillsGaps() throws {
        let entries = [
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "EUR", rate: 0.85),
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "GBP", rate: 0.74),
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "EUR", rate: 0.86),
        ]

        let response = try FrankfurterV2Mapper.historical(from: entries, base: "USD", startingOn: "2026-01-02")

        #expect(response.rates["2026-01-03"]?["EUR"] == 0.86)
        #expect(response.rates["2026-01-03"]?["GBP"] == 0.74)
    }

    @Test("historical does not backfill a currency before its first appearance")
    func historicalDoesNotBackfill() throws {
        let entries = [
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "EUR", rate: 0.85),
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "EUR", rate: 0.86),
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "GBP", rate: 0.74),
        ]

        let response = try FrankfurterV2Mapper.historical(from: entries, base: "USD", startingOn: "2026-01-02")

        #expect(response.rates["2026-01-02"]?["GBP"] == nil)
    }

    // MARK: - Boundary validation

    @Test("latest skips quotes that are not currency codes")
    func latestSkipsNonCurrencyQuotes() throws {
        let entries = [
            FrankfurterV2Rate(date: "2026-11-07", base: "USD", quote: "AAVE", rate: 0.0076287),
            FrankfurterV2Rate(date: "2026-11-08", base: "USD", quote: "EUR", rate: 0.89169),
            FrankfurterV2Rate(date: "2026-11-07", base: "USD", quote: "USDT", rate: 1.0016),
        ]

        let response = try FrankfurterV2Mapper.latest(from: entries, base: "USD")

        #expect(response.rates == ["EUR": 0.89169])
    }

    @Test("historical skips quotes that are not currency codes")
    func historicalSkipsNonCurrencyQuotes() throws {
        let entries = [
            FrankfurterV2Rate(date: "2026-11-05", base: "USD", quote: "EUR", rate: 0.88),
            FrankfurterV2Rate(date: "2026-11-05", base: "USD", quote: "USDT", rate: 1.0012),
            FrankfurterV2Rate(date: "2026-11-06", base: "USD", quote: "EUR", rate: 0.89),
            FrankfurterV2Rate(date: "2026-11-06", base: "USD", quote: "USDT", rate: 1.0016),
        ]

        let response = try FrankfurterV2Mapper.historical(from: entries, base: "USD", startingOn: "2026-11-05")

        #expect(response.rates == ["2026-11-05": ["EUR": 0.88], "2026-11-06": ["EUR": 0.89]])
    }

    @Test("latest leaves out three-letter crypto, which is not an ISO currency")
    func latestLeavesOutThreeLetterCrypto() throws {
        let entries = [
            FrankfurterV2Rate(date: "2026-11-10", base: "USD", quote: "BTC", rate: 0.0000097),
            FrankfurterV2Rate(date: "2026-11-10", base: "USD", quote: "ETH", rate: 0.00029),
            FrankfurterV2Rate(date: "2026-11-10", base: "USD", quote: "JPY", rate: 150),
        ]

        let response = try FrankfurterV2Mapper.latest(from: entries, base: "USD")

        #expect(response.rates == ["JPY": 150])
    }

    @Test("latest throws when no quote is a currency code")
    func latestThrowsWithoutCurrencyQuotes() {
        let entries = [FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "eur1", rate: 0.86)]
        #expect(throws: AppError.self) {
            _ = try FrankfurterV2Mapper.latest(from: entries, base: "USD")
        }
    }

    @Test("latest throws on non-positive or non-finite rates", arguments: [0.0, -1.5, Double.infinity, Double.nan])
    func latestThrowsOnBadRate(rate: Double) {
        let entries = [FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "EUR", rate: rate)]
        #expect(throws: AppError.self) {
            _ = try FrankfurterV2Mapper.latest(from: entries, base: "USD")
        }
    }

    @Test("historical throws on an unparseable date")
    func historicalThrowsOnBadDate() {
        let entries = [FrankfurterV2Rate(date: "not-a-date", base: "USD", quote: "EUR", rate: 0.86)]
        #expect(throws: AppError.self) {
            _ = try FrankfurterV2Mapper.historical(from: entries, base: "USD", startingOn: "2026-01-01")
        }
    }

    @Test("latest rejects an empty payload instead of synthesizing an empty snapshot")
    func latestThrowsOnEmptyPayload() {
        #expect(throws: AppError.self) {
            _ = try FrankfurterV2Mapper.latest(from: [], base: "USD")
        }
    }

    @Test("historical maps an empty payload to an empty response so the caller can record coverage")
    func historicalAcceptsEmptyPayload() throws {
        let response = try FrankfurterV2Mapper.historical(from: [], base: "USD", startingOn: "2026-01-02")

        #expect(response.rates.isEmpty)
        #expect(response.startDate.isEmpty)
        #expect(response.endDate.isEmpty)
    }
}
