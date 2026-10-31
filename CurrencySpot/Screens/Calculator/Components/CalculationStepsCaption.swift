import SwiftUI

struct CalculationStepsCaption: View {
    let text: String

    @State private var overflow = EdgeOverflow()
    @State private var position = ScrollPosition(edge: .trailing)

    private let fadeWidth: CGFloat = 24

    var body: some View {
        ScrollView(.horizontal) {
            Text(verbatim: text)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollPosition($position)
        .defaultScrollAnchor(.trailing, for: .initialOffset)
        .defaultScrollAnchor(.trailing, for: .sizeChanges)
        .defaultScrollAnchor(.trailing, for: .alignment)
        .onChange(of: text) {
            guard overflow.trailing > 1 else { return }
            withAnimation(.snappy) { position.scrollTo(edge: .trailing) }
        }
        .onScrollGeometryChange(for: EdgeOverflow.self, of: EdgeOverflow.init) { _, newValue in
            overflow = newValue
        }
        .mask { fadeMask }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(.calculatorStepsAccessibilityLabel)
        .accessibilityValue(Text(verbatim: text))
    }

    private var fadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: min(overflow.leading, fadeWidth))
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: min(overflow.trailing, fadeWidth))
        }
    }
}

private nonisolated struct EdgeOverflow: Equatable {
    var leading: CGFloat = 0
    var trailing: CGFloat = 0
}

private nonisolated extension EdgeOverflow {
    init(_ geometry: ScrollGeometry) {
        let hiddenLeading = geometry.contentOffset.x + geometry.contentInsets.leading
        let hiddenTrailing = geometry.contentSize.width - geometry.visibleRect.maxX
        self.init(leading: max(hiddenLeading, 0), trailing: max(hiddenTrailing, 0))
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: Spacing.section) {
        CalculationStepsCaption(text: "1,250 + 8 × 3")
        CalculationStepsCaption(text: "1,250 + 8 × 3 − 45.5 ÷ 2 + 120 × 4 + 99 − 12.75 × 2")
    }
    .font(.appHeadline.weight(.regular))
    .frame(width: 260)
    .padding()
}
