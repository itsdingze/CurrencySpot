//
//  View+ListSeparators.swift
//  CurrencySpot
//

import SwiftUI

extension View {
    /// Hides only a list row's outer separators — the top edge of the first row
    /// and the bottom edge of the last — leaving the dividers between rows intact.
    func hideOuterListSeparators(isFirst: Bool, isLast: Bool) -> some View {
        var edges: VerticalEdge.Set = []
        if isFirst { edges.insert(.top) }
        if isLast { edges.insert(.bottom) }
        return listRowSeparator(.hidden, edges: edges)
    }

    /// Index-based convenience for rows driven by `Array(items.enumerated())`.
    func hideOuterListSeparators(at index: Int, of count: Int) -> some View {
        hideOuterListSeparators(isFirst: index == 0, isLast: index == count - 1)
    }
}
