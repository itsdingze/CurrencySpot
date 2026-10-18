import SwiftUI

struct AdaptiveStack<Content: View>: View {
    var alignment: VerticalAlignment = .center
    var stackedAlignment: HorizontalAlignment = .leading
    var spacing: CGFloat?
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        layout { content }
            .frame(maxWidth: isStacked ? .infinity : nil, alignment: Alignment(horizontal: stackedAlignment, vertical: .center))
    }

    private var isStacked: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var layout: AnyLayout {
        if isStacked {
            AnyLayout(VStackLayout(alignment: stackedAlignment, spacing: spacing))
        } else {
            AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.block) {
        AdaptiveStack {
            Text(verbatim: "Default Base Currency")
            Spacer()
            Text(verbatim: "USD")
        }

        AdaptiveStack {
            Text(verbatim: "Default Base Currency")
            Spacer()
            Text(verbatim: "USD")
        }
        .dynamicTypeSize(.accessibility3)
    }
    .padding()
}
