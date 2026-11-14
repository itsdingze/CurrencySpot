import SwiftUI

extension View {
    func fitsFoldedScreen() -> some View {
        modifier(FoldFittedSheet())
    }

    func staysOnOnePageWhenFolded() -> some View {
        modifier(FoldedSheetPlacement())
    }
}

enum FoldedSheetFit {
    static func heightLimit(for layout: ScreenLayout, screenHeight: CGFloat) -> CGFloat? {
        guard layout == .tabletop, screenHeight > 0 else { return nil }
        return screenHeight / 2
    }

    static func detents(heightLimit: CGFloat?) -> Set<PresentationDetent> {
        guard let heightLimit else { return [.large] }
        return [.height(heightLimit)]
    }

    static func usesSolidBackground(in layout: ScreenLayout) -> Bool {
        layout == .tabletop || layout == .book
    }

    static func staysOnOnePage(in layout: ScreenLayout) -> Bool {
        layout == .book
    }

    static func page(openerPage: HorizontalEdge?, statusBarEdge: HorizontalEdge?) -> HorizontalEdge {
        openerPage ?? (statusBarEdge == .leading ? .leading : .trailing)
    }
}

private struct FoldFittedSheet: ViewModifier {
    @Environment(\.sheetHeightLimit) private var sheetHeightLimit
    @Environment(\.screenLayout) private var screenLayout

    func body(content: Content) -> some View {
        content
            // Branching around `content` itself gives it a new identity and restarts the sheet when the pose changes.
            .background {
                if FoldedSheetFit.usesSolidBackground(in: screenLayout) {
                    Color.clear.presentationBackground(BackgroundStyle())
                }
            }
            .presentationDetents(FoldedSheetFit.detents(heightLimit: sheetHeightLimit))
            .staysOnOnePageWhenFolded()
    }
}

private struct FoldedSheetPlacement: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(StatusBarPagePlacement())
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
private struct StatusBarPagePlacement: ViewModifier {
    @Environment(\.screenLayout) private var screenLayout
    @Environment(\.toolbarVerticalEdge) private var statusBarEdge
    @Environment(\.sheetOpenerPage) private var openerPage

    func body(content: Content) -> some View {
        content.presentationPlacement(placement)
    }

    private var placement: PresentationPlacement {
        guard FoldedSheetFit.staysOnOnePage(in: screenLayout) else { return .automatic }
        switch FoldedSheetFit.page(openerPage: openerPage, statusBarEdge: statusBarEdge) {
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}
