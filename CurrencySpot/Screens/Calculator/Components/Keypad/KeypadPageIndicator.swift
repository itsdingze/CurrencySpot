import SwiftUI

struct KeypadPageIndicator: View {
    @Binding var mode: CalculatorViewModel.KeypadMode

    private let modes = CalculatorViewModel.KeypadMode.allCases
    private let dotSize: CGFloat = 7

    var body: some View {
        HStack(spacing: 0) {
            ForEach(modes, id: \.self) { page in
                Button { mode = page } label: {
                    Circle()
                        .fill(page == mode ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .frame(width: dotSize, height: dotSize)
                        .padding(.horizontal, Spacing.tight / 2)
                }
                .buttonStyle(.plain)
                .layoutNeutralHitTarget(outerEdges(of: page))
                .accessibilityLabel(Text(page.title))
                .accessibilityAddTraits(page == mode ? .isSelected : [])
            }
        }
        .padding(.vertical, Spacing.hairline)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(.calculatorNumberPadAccessibilityLabel)
    }

    private func outerEdges(of page: CalculatorViewModel.KeypadMode) -> Edge.Set {
        var edges: Edge.Set = .vertical
        if page == modes.first { edges.insert(.leading) }
        if page == modes.last { edges.insert(.trailing) }
        return edges
    }
}

#Preview {
    @Previewable @State var mode = CalculatorViewModel.KeypadMode.amount

    KeypadPageIndicator(mode: $mode)
        .padding()
}
