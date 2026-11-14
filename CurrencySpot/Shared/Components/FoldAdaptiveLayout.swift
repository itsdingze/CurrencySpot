import SwiftUI

struct FoldAdaptiveLayout<Phone: View, Top: View, Bottom: View, Spare: View>: View {
    @Environment(\.screenLayout) private var screenLayout

    @ViewBuilder let phone: Phone
    @ViewBuilder let top: Top
    @ViewBuilder let bottom: Bottom
    @ViewBuilder let spare: Spare

    var body: some View {
        if #available(iOS 27.1, *), screenLayout == .tabletop {
            TabletopSplit {
                top
            } bottom: {
                bottom
            }
        } else {
            BookPageLayout {
                phone
            } spare: {
                spare
            }
        }
    }
}

extension FoldAdaptiveLayout where Spare == Color {
    init(
        @ViewBuilder phone: () -> Phone,
        @ViewBuilder top: () -> Top,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.init(phone: phone, top: top, bottom: bottom) { Color.clear }
    }
}

struct BookPageLayout<Content: View, Spare: View>: View {
    @Environment(\.screenLayout) private var screenLayout

    @ViewBuilder let content: Content
    @ViewBuilder let spare: Spare

    var body: some View {
        if #available(iOS 27.1, *), screenLayout == .book {
            StatusBarPage {
                content
            } spare: {
                spare
            }
        } else {
            content
        }
    }
}

extension BookPageLayout where Spare == Color {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content) { Color.clear }
    }
}

@available(iOS 27.1, *)
struct StatusBarPage<Content: View, Spare: View>: View {
    @Environment(\.toolbarVerticalEdge) private var statusBarEdge

    var foldInset: CGFloat = 0
    @ViewBuilder let content: Content
    @ViewBuilder let spare: Spare

    var body: some View {
        if statusBarEdge == .leading {
            ArrangementView { content.padding(.trailing, foldInset) } secondary: { readLast }
                .arrangementViewStyle(.split.axes(.horizontal))
        } else {
            ArrangementView { readLast } secondary: { content.padding(.leading, foldInset) }
                .arrangementViewStyle(.split.axes(.horizontal))
        }
    }

    private var readLast: some View {
        spare
            .accessibilityElement(children: .contain)
            .accessibilitySortPriority(-1)
    }
}

@available(iOS 27.1, *)
extension StatusBarPage where Spare == Color {
    init(foldInset: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.init(foldInset: foldInset, content: content) { Color.clear }
    }
}
