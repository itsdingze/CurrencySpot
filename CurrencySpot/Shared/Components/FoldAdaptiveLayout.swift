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
        } else if #available(iOS 27.1, *), screenLayout == .book {
            StatusBarPage {
                phone
            }
        } else {
            phone
        }
    }
}

@available(iOS 27.1, *)
private struct StatusBarPage<Content: View>: View {
    @Environment(\.toolbarVerticalEdge) private var statusBarEdge

    @ViewBuilder let content: Content

    var body: some View {
        if statusBarEdge == .leading {
            ArrangementView { content } secondary: { Color.clear }
                .arrangementViewStyle(.split.axes(.horizontal))
        } else {
            ArrangementView { Color.clear } secondary: { content }
                .arrangementViewStyle(.split.axes(.horizontal))
        }
    }
}
