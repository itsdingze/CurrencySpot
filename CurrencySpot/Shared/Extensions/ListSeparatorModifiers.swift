import SwiftUI

extension View {
    // List's native separators cache their hidden state against row identity and
    // mis-apply it after a move, so a reorderable list draws its own. Filling the
    // full cell height first is required: when row content is shorter than the
    // list's minimum row height, a bottom-anchored overlay floats above the cell's
    // true bottom edge.
    func rowSeparator(isLast: Bool) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Divider()
                        .padding(.leading, Spacing.cardPadding)
                        .allowsHitTesting(false)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }
}
