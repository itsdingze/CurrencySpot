import SwiftUI

@available(iOS 27.1, *)
struct TabletopSplit<Top: View, Bottom: View>: View {
    @ViewBuilder let top: Top
    @ViewBuilder let bottom: Bottom

    var body: some View {
        ArrangementView { top } secondary: { bottom }
            .arrangementViewStyle(.split.axes(.vertical))
    }
}
