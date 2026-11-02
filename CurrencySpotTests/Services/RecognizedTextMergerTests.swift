@testable import CurrencySpot
import CoreGraphics
import Foundation
import Testing

@Suite("Recognized Text Merger Tests")
struct RecognizedTextMergerTests {
    private func candidate(_ transcript: String, _ bounds: CGRect, confidence: Float) -> RecognizedTextCandidate {
        RecognizedTextCandidate(
            item: RecognizedTextItem(id: UUID(), transcript: transcript, bounds: bounds),
            confidence: confidence
        )
    }

    @Test("two reads of one line from overlapping bands become one, keeping the more confident read")
    func overlappingReadsOfOneLineKeepTheMoreConfident() {
        let doubtful = candidate("$1l.50", CGRect(x: 100, y: 1300, width: 300, height: 40), confidence: 0.5)
        let confident = candidate("$11.50", CGRect(x: 104, y: 1302, width: 296, height: 40), confidence: 0.9)

        let merged = RecognizedTextMerger.merge([doubtful, confident])

        #expect(merged == [confident.item])
    }

    @Test("a fragment one band read from inside a whole line yields to the line")
    func fragmentInsideALineYieldsToTheLine() {
        let line = candidate("Item 26 ........ $29.50", CGRect(x: 157, y: 2714, width: 319, height: 36), confidence: 1)
        let fragment = candidate(".. $29.50", CGRect(x: 341, y: 2715, width: 135, height: 35), confidence: 1)

        let merged = RecognizedTextMerger.merge([fragment, line])

        #expect(merged == [line.item])
    }

    @Test("a more confident fragment still yields to the whole line it came from")
    func confidentFragmentYieldsToTheWholeLine() {
        let line = candidate("Ramen ........ $12.50", CGRect(x: 40, y: 100, width: 300, height: 40), confidence: 0.9)
        let fragment = candidate("Ramen", CGRect(x: 40, y: 101, width: 90, height: 38), confidence: 1)

        let merged = RecognizedTextMerger.merge([line, fragment])

        #expect(merged == [line.item])
    }

    @Test("a whole line replaces every more confident fragment of it")
    func wholeLineReplacesEveryFragment() {
        let name = candidate("Ramen", CGRect(x: 40, y: 101, width: 90, height: 38), confidence: 1)
        let price = candidate("$12.50", CGRect(x: 250, y: 101, width: 90, height: 38), confidence: 1)
        let line = candidate("Ramen ........ $12.50", CGRect(x: 40, y: 100, width: 300, height: 40), confidence: 0.9)

        let merged = RecognizedTextMerger.merge([name, price, line])

        #expect(merged == [line.item])
    }

    @Test("a short line inside a tilted neighbor's box is kept when its text differs")
    func shortLineInsideATiltedNeighborsBoxIsKept() {
        let soup = candidate("Soup $11.50", CGRect(x: 64, y: 154, width: 177, height: 56), confidence: 1)
        let grilledDish = candidate(
            "Grilled dish number 2 with seasonal vegetables ........ $12.50",
            CGRect(x: 69, y: 156, width: 809, height: 105),
            confidence: 1
        )

        let merged = RecognizedTextMerger.merge([soup, grilledDish])

        #expect(merged == [soup.item, grilledDish.item])
    }

    @Test("a read too short to identify a line is kept even when a neighbor's text contains it")
    func shortReadContainedByChanceIsKept() {
        let price = candidate("¥480", CGRect(x: 60, y: 200, width: 120, height: 40), confidence: 1)
        let setMenu = candidate("Set B ........ ¥1,480", CGRect(x: 40, y: 190, width: 700, height: 90), confidence: 1)

        let merged = RecognizedTextMerger.merge([price, setMenu])

        #expect(merged == [price.item, setMenu.item])
    }

    @Test("separate lines are all kept in the order they were read")
    func separateLinesAreAllKeptInOrder() {
        let lines = [
            candidate("Ramen ¥850", CGRect(x: 40, y: 100, width: 300, height: 40), confidence: 0.6),
            candidate("Gyoza ¥480", CGRect(x: 40, y: 160, width: 300, height: 40), confidence: 1),
            candidate("Beer ¥600", CGRect(x: 40, y: 220, width: 300, height: 40), confidence: 0.8),
        ]

        let merged = RecognizedTextMerger.merge(lines)

        #expect(merged == lines.map(\.item))
    }
}
