import SwiftUI
import Testing
@testable import CurrencySpot

struct SheetFittingDetentsTests {
    @Test func sheetOpensAtMediumHeightBeforeItsContentIsMeasured() {
        let detents = SheetFittingDetents.detents(fittedHeight: nil, fullHeightThreshold: 600)

        #expect(detents == [.medium])
    }

    @Test(arguments: [CGFloat(300), 600])
    func sheetIsAsTallAsContentThatFitsUnderTheThreshold(fittedHeight: CGFloat) {
        let detents = SheetFittingDetents.detents(fittedHeight: fittedHeight, fullHeightThreshold: 600)

        #expect(detents == [.height(fittedHeight)])
    }

    @Test func sheetOpensFullHeightWhenContentIsTallerThanTheThreshold() {
        let detents = SheetFittingDetents.detents(fittedHeight: 601, fullHeightThreshold: 600)

        #expect(detents == [.large])
    }
}
