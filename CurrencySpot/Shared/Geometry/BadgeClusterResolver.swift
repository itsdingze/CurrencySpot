import CoreGraphics
import Foundation

struct BadgeClusterResolver {
    struct Badge {
        let id: UUID
        let frame: CGRect
        let boxMidY: CGFloat
    }

    let horizontalOverlapTolerance: CGFloat
    let verticalOverlapTolerance: CGFloat

    func depths(for badges: [Badge], promotions: [UUID]) -> [UUID: Int] {
        var depths: [UUID: Int] = [:]
        for cluster in clusters(of: badges) {
            for (depth, index) in rank(cluster, in: badges, promotions: promotions).enumerated() {
                depths[badges[index].id] = depth
            }
        }
        return depths
    }

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

    private func clustered(_ a: Badge, _ b: Badge) -> Bool {
        let ra = a.frame, rb = b.frame
        guard ra.intersects(rb) else { return false }
        let overlapX = min(ra.maxX, rb.maxX) - max(ra.minX, rb.minX)
        let overlapY = min(ra.maxY, rb.maxY) - max(ra.minY, rb.minY)
        return overlapX > horizontalOverlapTolerance * min(ra.width, rb.width)
            && overlapY > verticalOverlapTolerance * min(ra.height, rb.height)
    }
}
