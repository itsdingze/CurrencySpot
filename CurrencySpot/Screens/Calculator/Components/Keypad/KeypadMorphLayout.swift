import SwiftUI

nonisolated struct KeySlotKey: LayoutValueKey {
    static let defaultValue = KeySlot()
}

struct KeypadMorphLayout: Layout {
    var progress: CGFloat
    var spacing: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        if let height = proposal.height { return CGSize(width: width, height: height) }
        let keyHeight = max(subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0, ControlMetrics.buttonSize)
        let rows = 4 + min(max(progress, 0), 1)
        return CGSize(width: width, height: rows * keyHeight + (rows - 1) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let geometry = KeypadGeometry(bounds: bounds, spacing: spacing)
        for subview in subviews {
            let frame = geometry.frame(for: subview[KeySlotKey.self], progress: progress)
            subview.place(at: frame.origin, proposal: ProposedViewSize(frame.size))
        }
    }
}
