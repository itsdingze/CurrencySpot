//
//  BadgeClusterResolverTests.swift
//  CurrencySpotTests
//

import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

struct BadgeClusterResolverTests {
    /// 60×24 badge at `frame`, owned by a box centered vertically at `boxMidY`.
    private static func badge(
        _ id: UUID,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 60,
        height: CGFloat = 24,
        boxMidY: CGFloat
    ) -> BadgeClusterResolver.Badge {
        BadgeClusterResolver.Badge(
            id: id,
            frame: CGRect(x: x, y: y, width: width, height: height),
            boxMidY: boxMidY
        )
    }

    /// Tolerates up to 1/4 horizontal overlap (15pt of 60) and 1/3 vertical
    /// overlap (8pt of 24).
    private static let resolver = BadgeClusterResolver(
        horizontalOverlapTolerance: 0.25,
        verticalOverlapTolerance: 1.0 / 3.0
    )

    @Test func nonIntersectingBadgesAreAllDepthZero() {
        let a = UUID(), b = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 200, y: 0, boxMidY: 100),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 0])
    }

    /// Frames touch but overlap is within both tolerances, so no cluster forms.
    @Test func intersectionWithinBothTolerancesDoesNotCluster() {
        let a = UUID(), b = UUID()
        // 10pt horizontal overlap (< 15) and 6pt vertical overlap (< 8).
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 50, y: 18, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 0])
    }

    /// A wide but shallow intersection is a sliver, not an overlap: two
    /// same-column badges grazing vertically stay full opacity.
    @Test func horizontalOnlyBreachDoesNotCluster() {
        let a = UUID(), b = UUID()
        // 40pt horizontal overlap (> 15), 6pt vertical overlap (< 8).
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 20, y: 18, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 0])
    }

    /// A tall but thin intersection is a sliver, not an overlap: two same-row
    /// badges touching horizontally stay full opacity.
    @Test func verticalOnlyBreachDoesNotCluster() {
        let a = UUID(), b = UUID()
        // 10pt horizontal overlap (< 15), 18pt vertical overlap (> 8).
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 50, y: 6, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 0])
    }

    /// Same-row badges touching by a point breach the vertical tolerance
    /// trivially (full shared height) — they must not dim on a mere touch.
    @Test func sameRowOnePointTouchDoesNotCluster() {
        let a = UUID(), b = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 59, y: 0, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 0])
    }

    /// Only an intersection substantial on both axes clusters.
    @Test func breachOnBothAxesClusters() {
        let a = UUID(), b = UUID()
        // 40pt horizontal overlap (> 15), 18pt vertical overlap (> 8).
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 20, y: 6, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 1])
    }

    /// Default front is the visually higher box (smaller boxMidY), regardless of
    /// input order.
    @Test func defaultFrontIsSmallerBoxMidYRegardlessOfInputOrder() {
        let high = UUID(), low = UUID()
        // Listed low-first to prove input order does not decide the front.
        let depths = Self.resolver.depths(
            for: [
                Self.badge(low, x: 0, y: 0, boxMidY: 300),
                Self.badge(high, x: 0, y: 0, boxMidY: 100),
            ],
            promotions: []
        )

        #expect(depths == [high: 0, low: 1])
    }

    /// A promoted badge moves to the front; the rest re-grade behind it.
    @Test func promotionReordersToFront() {
        let high = UUID(), low = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(high, x: 0, y: 0, boxMidY: 100),
                Self.badge(low, x: 0, y: 0, boxMidY: 300),
            ],
            promotions: [low]
        )

        #expect(depths == [low: 0, high: 1])
    }

    /// The most recent promotion (last in the array) wins the front slot.
    @Test func mostRecentPromotionWins() {
        let a = UUID(), b = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 0, y: 0, boxMidY: 300),
            ],
            promotions: [a, b]
        )

        #expect(depths == [b: 0, a: 1])
    }

    /// Promoting a badge that clusters with nothing changes nothing.
    @Test func promotingNonClusteredBadgeIsNoOp() {
        let a = UUID(), b = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 200, y: 0, boxMidY: 100),
            ],
            promotions: [b]
        )

        #expect(depths == [a: 0, b: 0])
    }

    /// A–B and B–C clustered (but not A–C) forms one connected component with
    /// depths 0/1/2 ranked by box height.
    @Test func chainFormsOneClusterWithGradedDepths() {
        let a = UUID(), b = UUID(), c = UUID()
        // Horizontal chain: A∩B and B∩C breach, A and C are far apart.
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 40, y: 0, boxMidY: 200),
                Self.badge(c, x: 80, y: 0, boxMidY: 300),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 1, c: 2])
    }

    /// Equal boxMidY breaks ties by stable input order.
    @Test func boxMidYTieBreaksByInputOrder() {
        let first = UUID(), second = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(first, x: 0, y: 0, boxMidY: 200),
                Self.badge(second, x: 0, y: 0, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [first: 0, second: 1])
    }
}
