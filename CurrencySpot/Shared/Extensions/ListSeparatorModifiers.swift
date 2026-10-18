import SwiftUI

extension View {
    // List separators mis-apply hidden state after a move, and the overlay floats above short rows unless it fills the cell.
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
