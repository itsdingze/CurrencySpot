//
//  FrankfurterV2MapperTests.swift
//  CurrencySpotTests
//

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

        let response = try FrankfurterV2Mapper.historical(from: entries, base: "USD")

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
            // 2026-01-03: GBP did not publish
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "EUR", rate: 0.86),
        ]

        let response = try FrankfurterV2Mapper.historical(from: entries, base: "USD")

        #expect(response.rates["2026-01-03"]?["EUR"] == 0.86)
        #expect(response.rates["2026-01-03"]?["GBP"] == 0.74) // carried forward from 01-02
    }

    @Test("historical does not backfill a currency before its first appearance")
    func historicalDoesNotBackfill() throws {
        let entries = [
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "EUR", rate: 0.85),
            // GBP only appears on 01-03
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "EUR", rate: 0.86),
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "GBP", rate: 0.74),
        ]

        let response = try FrankfurterV2Mapper.historical(from: entries, base: "USD")

        #expect(response.rates["2026-01-02"]?["GBP"] == nil)
    }

    // MARK: - Boundary validation

    @Test("latest throws on an invalid currency code")
    func latestThrowsOnBadCode() {
        let entries = [FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "eur1", rate: 0.86)]
        #expect(throws: Error.self) {
            _ = try FrankfurterV2Mapper.latest(from: entries, base: "USD")
        }
    }

    @Test("latest throws on non-positive or non-finite rates", arguments: [0.0, -1.5, Double.infinity, Double.nan])
    func latestThrowsOnBadRate(rate: Double) {
        let entries = [FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "EUR", rate: rate)]
        #expect(throws: Error.self) {
            _ = try FrankfurterV2Mapper.latest(from: entries, base: "USD")
        }
    }

    @Test("historical throws on an unparseable date")
    func historicalThrowsOnBadDate() {
        let entries = [FrankfurterV2Rate(date: "not-a-date", base: "USD", quote: "EUR", rate: 0.86)]
        #expect(throws: Error.self) {
            _ = try FrankfurterV2Mapper.historical(from: entries, base: "USD")
        }
    }
}
