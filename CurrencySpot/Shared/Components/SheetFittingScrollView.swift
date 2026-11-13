import SwiftUI

struct SheetFittingScrollView<Content: View>: View {
    private let paddedEdges: Edge.Set
    private let fullHeightThreshold: CGFloat
    private let content: Content

    @State private var fittedHeight: CGFloat?
    @Environment(\.sheetHeightLimit) private var sheetHeightLimit

    init(
        padding paddedEdges: Edge.Set = .all,
        fullHeightThreshold: CGFloat = .infinity,
        @ViewBuilder content: () -> Content
    ) {
        self.paddedEdges = paddedEdges
        self.fullHeightThreshold = fullHeightThreshold
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .padding(paddedEdges)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentSize.height + geometry.contentInsets.top
        } action: { _, height in
            fittedHeight = height
        }
        .presentationDetents(
            SheetFittingDetents.detents(
                fittedHeight: fittedHeight,
                fullHeightThreshold: fullHeightThreshold,
                heightLimit: sheetHeightLimit
            )
        )
        .staysOnOnePageWhenFolded()
    }
}

nonisolated enum SheetFittingDetents {
    static func detents(
        fittedHeight: CGFloat?,
        fullHeightThreshold: CGFloat,
        heightLimit: CGFloat? = nil
    ) -> Set<PresentationDetent> {
        guard let heightLimit else {
            guard let fittedHeight else { return [.medium] }
            guard fittedHeight <= fullHeightThreshold else { return [.large] }
            return [.height(fittedHeight)]
        }
        guard let fittedHeight else { return [.height(heightLimit)] }
        return [.height(min(fittedHeight, heightLimit))]
    }
}

#Preview {
    @Previewable @State var isPresented = true

    Button { isPresented = true } label: { Text(verbatim: "Show sheet") }
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                SheetFittingScrollView {
                    Text(verbatim: "The sheet is as tall as this text plus its padding.")
                }
                .navigationTitle(Text(verbatim: "Fitted Sheet"))
                .toolbarTitleDisplayMode(.inline)
            }
        }
}
