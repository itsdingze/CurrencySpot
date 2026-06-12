//
//  BadgeClusterResolver.swift
//  CurrencySpot
//

import CoreGraphics
import Foundation

/// Ranks overlapping converted-price badges front-to-back so the overlay can
/// dim and z-order them. Badges never move; overlap is resolved by focus.
///
/// Two badges cluster only when their intersection is substantial on *both*
/// axes — a sliver thin on either axis is tolerated, so a mere touch never
/// dims. Clusters are the connected components of that pairwise relation.
/// Everything is single-pass — there is no iterate-until-settled loop.
struct BadgeClusterResolver {
    /// One badge to rank. All values are in the overlay's view space.
    struct Badge {
        let id: UUID
        /// Anchored center plus measured size.
        let frame: CGRect
        /// Owning box's vertical center; the higher box fronts by default.
        let boxMidY: CGFloat
    }

    /// Fraction of the narrower badge's width two badges may overlap before
    /// they count as clustered.
    let horizontalOverlapTolerance: CGFloat
    /// Fraction of the shorter badge's height two badges may overlap before
    /// they count as clustered.
    let verticalOverlapTolerance: CGFloat

    /// Depth rank per badge: 0 = front of its cluster. Non-clustered badges
    /// are depth 0. `promotions` is ordered, most recent last.
    func depths(for badges: [Badge], promotions: [UUID]) -> [UUID: Int] {
        var depths: [UUID: Int] = [:]
        for cluster in clusters(of: badges) {
            for (depth, index) in rank(cluster, in: badges, promotions: promotions).enumerated() {
                depths[badges[index].id] = depth
            }
        }
        return depths
    }

    /// Connected components of the clustering relation, as index groups.
    private func clusters(of badges: [Badge]) -> [[Int]] {
        var parent = Array(badges.indices)
        func root(_ i: Int) -> Int {
            var i = i
            while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }
            return i
        }
        for i in badges.indices {
            for j in badges.indices where j > i && clustered(badges[i], badges[j]) {
                parent[root(i)] = root(j)
            }
        }

        var groups: [Int: [Int]] = [:]
        for i in badges.indices { groups[root(i), default: []].append(i) }
        return Array(groups.values)
    }

    /// Cluster members ordered front-to-back: most recent promotion first, then
    /// higher box (smaller `boxMidY`), then stable input order.
    private func rank(_ cluster: [Int], in badges: [Badge], promotions: [UUID]) -> [Int] {
        cluster.sorted { lhs, rhs in
            let lp = promotions.lastIndex(of: badges[lhs].id)
            let rp = promotions.lastIndex(of: badges[rhs].id)
            if lp != rp { return (lp ?? -1) > (rp ?? -1) }
            if badges[lhs].boxMidY != badges[rhs].boxMidY {
                return badges[lhs].boxMidY < badges[rhs].boxMidY
            }
            return lhs < rhs
        }
    }

    /// True when the frames intersect and breach both overlap tolerances.
    private func clustered(_ a: Badge, _ b: Badge) -> Bool {
        let ra = a.frame, rb = b.frame
        guard ra.intersects(rb) else { return false }
        let overlapX = min(ra.maxX, rb.maxX) - max(ra.minX, rb.minX)
        let overlapY = min(ra.maxY, rb.maxY) - max(ra.minY, rb.minY)
        return overlapX > horizontalOverlapTolerance * min(ra.width, rb.width)
            && overlapY > verticalOverlapTolerance * min(ra.height, rb.height)
    }
}
