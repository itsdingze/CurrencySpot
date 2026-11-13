import SwiftUI

struct FoldAdaptiveLayout<Phone: View, Top: View, Bottom: View>: View {
    @Environment(\.screenLayout) private var screenLayout

    @ViewBuilder let phone: Phone
    @ViewBuilder let top: Top
    @ViewBuilder let bottom: Bottom

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
            }
        }
    }
}

struct BookPageLayout<Content: View>: View {
    @Environment(\.screenLayout) private var screenLayout

    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 27.1, *), screenLayout == .book {
            StatusBarPage {
                content
            }
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
struct StatusBarPage<Content: View>: View {
    @Environment(\.toolbarVerticalEdge) private var statusBarEdge

    var foldInset: CGFloat = 0
    @ViewBuilder let content: Content

    var body: some View {
        if statusBarEdge == .leading {
            ArrangementView { content.padding(.trailing, foldInset) } secondary: { Color.clear }
                .arrangementViewStyle(.split.axes(.horizontal))
        } else {
            ArrangementView { Color.clear } secondary: { content.padding(.leading, foldInset) }
                .arrangementViewStyle(.split.axes(.horizontal))
        }
    }
}
