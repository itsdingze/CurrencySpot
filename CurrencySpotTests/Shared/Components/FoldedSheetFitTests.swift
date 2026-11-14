import SwiftUI
import Testing
@testable import CurrencySpot

struct FoldedSheetFitTests {
    @Test("a sheet stops at the fold when the screen is half open on a table")
    func tabletopLimitsSheetsToTheLowerHalf() {
        #expect(FoldedSheetFit.heightLimit(for: .tabletop, screenHeight: 951) == 475.5)
    }

    @Test(
        "a sheet keeps its full height in every other pose",
        arguments: [ScreenLayout.compact, .wide, .book, .tent]
    )
    func otherLayoutsDoNotLimitSheetHeight(layout: ScreenLayout) {
        #expect(FoldedSheetFit.heightLimit(for: layout, screenHeight: 951) == nil)
    }

    @Test func aLimitedSheetRestsAtTheLimit() {
        #expect(FoldedSheetFit.detents(heightLimit: 475.5) == [.height(475.5)])
    }

    @Test func anUnlimitedSheetIsFullHeight() {
        #expect(FoldedSheetFit.detents(heightLimit: nil) == [.large])
    }

    @Test("a sheet's own background is solid in the folded poses, where the system's would show through as a different color")
    func foldedPosesUseASolidBackground() {
        #expect(FoldedSheetFit.usesSolidBackground(in: .tabletop))
        #expect(FoldedSheetFit.usesSolidBackground(in: .book))
        #expect(!FoldedSheetFit.usesSolidBackground(in: .compact))
        #expect(!FoldedSheetFit.usesSolidBackground(in: .wide))
        #expect(!FoldedSheetFit.usesSolidBackground(in: .tent))
    }

    @Test("a sheet sits on one page only when the screen is half open like a book")
    func onlyBookKeepsSheetsOnOnePage() {
        #expect(FoldedSheetFit.staysOnOnePage(in: .book))
        #expect(!FoldedSheetFit.staysOnOnePage(in: .wide))
        #expect(!FoldedSheetFit.staysOnOnePage(in: .tabletop))
        #expect(!FoldedSheetFit.staysOnOnePage(in: .compact))
        #expect(!FoldedSheetFit.staysOnOnePage(in: .tent))
    }

    @Test("a sheet opens on the page of the button that opened it")
    func sheetFollowsItsOpenerPage() {
        #expect(FoldedSheetFit.page(openerPage: .leading, statusBarEdge: .trailing) == .leading)
        #expect(FoldedSheetFit.page(openerPage: .trailing, statusBarEdge: .leading) == .trailing)
    }

    @Test("a sheet with no known opener page sits beside the status bar")
    func sheetDefaultsToTheStatusBarPage() {
        #expect(FoldedSheetFit.page(openerPage: nil, statusBarEdge: .leading) == .leading)
        #expect(FoldedSheetFit.page(openerPage: nil, statusBarEdge: .trailing) == .trailing)
        #expect(FoldedSheetFit.page(openerPage: nil, statusBarEdge: nil) == .trailing)
    }
}
