//
//  RateRefreshPolicyTests.swift
//  CurrencySpotTests
//

import Foundation
import Testing
@testable import CurrencySpot

@Suite("RateRefreshPolicy")
struct RateRefreshPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("refetches when there is no previous fetch")
    func refetchesWithNoHistory() {
        #expect(RateRefreshPolicy.shouldRefetch(now: now, lastFetch: nil) == true)
    }

    @Test("does not refetch within the freshness window")
    func keepsFreshWithinTTL() {
        let lastFetch = now.addingTimeInterval(-3 * 60 * 60) // 3h ago, ttl 6h
        #expect(RateRefreshPolicy.shouldRefetch(now: now, lastFetch: lastFetch) == false)
    }

    @Test("refetches once the freshness window has elapsed")
    func refetchesAfterTTL() {
        let lastFetch = now.addingTimeInterval(-7 * 60 * 60) // 7h ago, ttl 6h
        #expect(RateRefreshPolicy.shouldRefetch(now: now, lastFetch: lastFetch) == true)
    }
}
