import Foundation

struct BadgePriceOverrides {
    private var pinned: Set<UUID> = []
    private var suppressed: Set<UUID> = []

    func effective(_ conversion: ScannedConversion, for id: UUID) -> ScannedConversion {
        if pinned.contains(id) { return conversion.asPrice }
        if suppressed.contains(id) { return conversion.asNonPrice }
        return conversion
    }

    mutating func toggle(id: UUID, isPrice: Bool) {
        if isPrice {
            if pinned.contains(id) {
                pinned.remove(id)
            } else {
                suppressed.insert(id)
            }
        } else {
            if suppressed.contains(id) {
                suppressed.remove(id)
            } else {
                pinned.insert(id)
            }
        }
    }

    mutating func hide(id: UUID) {
        if pinned.contains(id) {
            pinned.remove(id)
        } else {
            suppressed.insert(id)
        }
    }
}
