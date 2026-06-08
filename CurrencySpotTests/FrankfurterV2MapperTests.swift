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
    func latestMapsRates() {
        let entries = [
            FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "EUR", rate: 0.86),
            FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "GBP", rate: 0.74),
        ]

        let response = FrankfurterV2Mapper.latest(from: entries, base: "USD")

        #expect(response.base == "USD")
        #expect(response.rates["EUR"] == 0.86)
        #expect(response.rates["GBP"] == 0.74)
    }

    @Test("latest collapses mixed per-currency dates to the most recent")
    func latestUsesMaxDate() {
        let entries = [
            FrankfurterV2Rate(date: "2026-06-05", base: "USD", quote: "ALL", rate: 81.7),
            FrankfurterV2Rate(date: "2026-06-07", base: "USD", quote: "EUR", rate: 0.86),
            FrankfurterV2Rate(date: "2026-06-06", base: "USD", quote: "BIF", rate: 2985.0),
        ]

        let response = FrankfurterV2Mapper.latest(from: entries, base: "USD")

        #expect(response.date == "2026-06-07")
    }

    @Test("historical regroups the flat v2 array into per-date keyed rates")
    func historicalRegroupsByDate() {
        let entries = [
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "EUR", rate: 0.85),
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "GBP", rate: 0.74),
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "EUR", rate: 0.86),
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "GBP", rate: 0.75),
        ]

        let response = FrankfurterV2Mapper.historical(from: entries, base: "USD")

        #expect(response.base == "USD")
        #expect(response.start_date == "2026-01-02")
        #expect(response.end_date == "2026-01-03")
        #expect(response.rates["2026-01-02"]?["EUR"] == 0.85)
        #expect(response.rates["2026-01-03"]?["GBP"] == 0.75)
    }

    @Test("historical forward-fills a currency missing on a later date")
    func historicalForwardFillsGaps() {
        let entries = [
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "EUR", rate: 0.85),
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "GBP", rate: 0.74),
            // 2026-01-03: GBP did not publish
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "EUR", rate: 0.86),
        ]

        let response = FrankfurterV2Mapper.historical(from: entries, base: "USD")

        #expect(response.rates["2026-01-03"]?["EUR"] == 0.86)
        #expect(response.rates["2026-01-03"]?["GBP"] == 0.74) // carried forward from 01-02
    }

    @Test("historical does not backfill a currency before its first appearance")
    func historicalDoesNotBackfill() {
        let entries = [
            FrankfurterV2Rate(date: "2026-01-02", base: "USD", quote: "EUR", rate: 0.85),
            // GBP only appears on 01-03
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "EUR", rate: 0.86),
            FrankfurterV2Rate(date: "2026-01-03", base: "USD", quote: "GBP", rate: 0.74),
        ]

        let response = FrankfurterV2Mapper.historical(from: entries, base: "USD")

        #expect(response.rates["2026-01-02"]?["GBP"] == nil)
    }
}
