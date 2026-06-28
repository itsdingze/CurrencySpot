//
//  BadgePriceOverrides.swift
//  CurrencySpot
//

import Foundation

/// The user's per-item badge overrides for a scanned frame: numbers the classifier
/// skipped that the user pinned as prices, and auto-detected prices the user dismissed.
/// Tap toggles in either direction; the detail sheet's "hide" only uncovers a price.
struct BadgePriceOverrides {
    private var pinned: Set<UUID> = []
    private var suppressed: Set<UUID> = []

    /// Applies the user's override to a classifier verdict for `id`.
    func effective(
        _ conversion: ScanConversionUseCase.ScannedConversion,
        for id: UUID
    ) -> ScanConversionUseCase.ScannedConversion {
        if pinned.contains(id) { return conversion.asPrice }
        if suppressed.contains(id) { return conversion.asNonPrice }
        return conversion
    }

    /// Outline tap: pin a skipped number as a price, or dismiss a pinned/auto price.
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

    /// Detail-sheet escape hatch: uncover a pinned/auto price's original text.
    mutating func hide(id: UUID) {
        if pinned.contains(id) {
            pinned.remove(id)
        } else {
            suppressed.insert(id)
        }
    }
}
