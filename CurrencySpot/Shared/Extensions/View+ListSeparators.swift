//
//  View+ListSeparators.swift
//  CurrencySpot
//

import SwiftUI

extension View {
    /// Self-drawn row separator for *interactive* (reorderable) lists. List's
    /// native separators cache their hidden state against row identity and
    /// mis-apply it after a move (a stale divider on the old last row, none on the
    /// new one). Drawing the divider as ordinary row content, keyed off `isLast`,
    /// recomputes every render and tracks the current order through a reorder.
    ///
    /// Removes the default row insets, so the row content must supply its own
    /// padding (e.g. `.padding(.vertical, .elementGap).padding(.horizontal, .cardPadding)`).
    /// Then hides the native separator and draws a leading-inset hairline at the
    /// bottom edge of every row but the last.
    ///
    /// Static lists don't hit the caching bug — use `.listSectionSeparator(.hidden)`
    /// there instead.
    func rowSeparator(isLast: Bool) -> some View {
        // Fill the full cell height first: when the row content is shorter than the
        // list's minimum row height, the cell is taller than the content, and an
        // overlay anchored to the content would float above the cell's true bottom.
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Divider()
                        .padding(.leading, .cardPadding)
                        .allowsHitTesting(false)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }
}
