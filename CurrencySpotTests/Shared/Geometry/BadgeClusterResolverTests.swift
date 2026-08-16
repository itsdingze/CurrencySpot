import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

struct BadgeClusterResolverTests {
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

    @Test func intersectionWithinBothTolerancesDoesNotCluster() {
        let a = UUID(), b = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 50, y: 18, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 0])
    }

    @Test func horizontalOnlyBreachDoesNotCluster() {
        let a = UUID(), b = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 20, y: 18, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 0])
    }

    @Test func verticalOnlyBreachDoesNotCluster() {
        let a = UUID(), b = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 50, y: 6, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 0])
    }

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

    @Test func breachOnBothAxesClusters() {
        let a = UUID(), b = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(a, x: 0, y: 0, boxMidY: 100),
                Self.badge(b, x: 20, y: 6, boxMidY: 200),
            ],
            promotions: []
        )

        #expect(depths == [a: 0, b: 1])
    }

    @Test func defaultFrontIsSmallerBoxMidYRegardlessOfInputOrder() {
        let high = UUID(), low = UUID()
        let depths = Self.resolver.depths(
            for: [
                Self.badge(low, x: 0, y: 0, boxMidY: 300),
                Self.badge(high, x: 0, y: 0, boxMidY: 100),
            ],
            promotions: []
        )

        #expect(depths == [high: 0, low: 1])
    }

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

    @Test func chainFormsOneClusterWithGradedDepths() {
        let a = UUID(), b = UUID(), c = UUID()
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
