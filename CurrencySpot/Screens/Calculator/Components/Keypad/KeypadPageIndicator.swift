import SwiftUI

struct KeypadPageIndicator: View {
    @Binding var mode: CalculatorViewModel.KeypadMode

    private let modes = CalculatorViewModel.KeypadMode.allCases
    private let dotSize: CGFloat = 7

    var body: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(modes, id: \.self) { page in
                Button { mode = page } label: {
                    Circle()
                        .fill(page == mode ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .frame(width: dotSize, height: dotSize)
                }
                .buttonStyle(.plain)
                .layoutNeutralHitTarget()
                .accessibilityLabel(Text(page.title))
                .accessibilityAddTraits(page == mode ? .isSelected : [])
            }
        }
        .padding(.vertical, Spacing.hairline)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(.calculatorNumberPadAccessibilityLabel)
    }
}

#Preview {
    @Previewable @State var mode = CalculatorViewModel.KeypadMode.amount

    KeypadPageIndicator(mode: $mode)
        .padding()
}
