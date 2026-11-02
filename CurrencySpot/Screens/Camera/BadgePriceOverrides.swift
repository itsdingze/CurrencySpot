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
            hide(id: id)
        } else {
            show(id: id)
        }
    }

    mutating func hide(id: UUID) {
        pinned.remove(id)
        suppressed.insert(id)
    }

    private mutating func show(id: UUID) {
        suppressed.remove(id)
        pinned.insert(id)
    }
}
