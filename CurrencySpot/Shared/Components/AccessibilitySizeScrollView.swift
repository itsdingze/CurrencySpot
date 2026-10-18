import SwiftUI

struct AccessibilitySizeScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView { content }
        } else {
            content
        }
    }
}

#Preview {
    AccessibilitySizeScrollView {
        VStack(spacing: Spacing.element) {
            ForEach(1 ... 12, id: \.self) { row in
                Text(verbatim: "Row \(row)")
            }
        }
    }
    .dynamicTypeSize(.accessibility5)
}
