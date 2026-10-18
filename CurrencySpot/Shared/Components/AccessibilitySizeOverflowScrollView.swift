import SwiftUI

struct AccessibilitySizeOverflowScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ViewThatFits(in: .vertical) {
                content

                ScrollView { content }
            }
        } else {
            content
        }
    }
}

#Preview {
    AccessibilitySizeOverflowScrollView {
        VStack(spacing: Spacing.element) {
            Spacer()

            ForEach(1 ... 3, id: \.self) { row in
                Text(verbatim: "Row \(row)")
            }

            Spacer()
        }
    }
    .dynamicTypeSize(.accessibility1)
}
