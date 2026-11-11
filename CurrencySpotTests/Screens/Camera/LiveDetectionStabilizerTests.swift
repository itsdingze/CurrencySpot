import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

struct LiveDetectionStabilizerTests {
    private let id = UUID()

    private func reading(
        _ amount: Decimal,
        isPrice: Bool,
        transcript: String = "",
        bounds: CGRect = .zero
    ) -> DetectedItem {
        DetectedItem(
            id: id,
            transcript: transcript,
            bounds: bounds,
            conversion: .init(amount: amount, converted: amount / 100, isPrice: isPrice)
        )
    }

    @Test func theFirstReadingShowsImmediately() {
        var stabilizer = LiveDetectionStabilizer()

        stabilizer.record([reading(1200, isPrice: true)])

        #expect(stabilizer.items == [reading(1200, isPrice: true)])
    }

    @Test func aFrameRepeatingAnItemShowsItOnce() {
        var stabilizer = LiveDetectionStabilizer()

        stabilizer.record([reading(1200, isPrice: true), reading(450, isPrice: true)])

        #expect(stabilizer.items.count == 1)
    }

    @Test func oneOutlineReadingKeepsThePlate() {
        var stabilizer = LiveDetectionStabilizer()
        stabilizer.record([reading(1200, isPrice: true)])

        stabilizer.record([reading(1200, isPrice: false)])

        #expect(stabilizer.items.first?.conversion.isPrice == true)
    }

    @Test func aSustainedChangeWins() {
        var stabilizer = LiveDetectionStabilizer()
        stabilizer.record([reading(1200, isPrice: true)])

        stabilizer.record([reading(1200, isPrice: false)])
        stabilizer.record([reading(1200, isPrice: false)])

        #expect(stabilizer.items.first?.conversion.isPrice == false)
    }

    @Test func aMisreadAmountKeepsTheSteadyAmountAndItsTranscript() {
        var stabilizer = LiveDetectionStabilizer()
        stabilizer.record([reading(1200, isPrice: true, transcript: "¥1,200")])
        stabilizer.record([reading(1200, isPrice: true, transcript: "¥1,200")])

        stabilizer.record([reading(1280, isPrice: true, transcript: "¥1,280")])

        #expect(stabilizer.items == [reading(1200, isPrice: true, transcript: "¥1,200")])
    }

    @Test func boundsSettleOnASustainedMove() {
        var stabilizer = LiveDetectionStabilizer()
        let moved = CGRect(x: 40, y: 80, width: 100, height: 30)
        stabilizer.record([reading(1200, isPrice: true)])

        stabilizer.record([reading(1200, isPrice: false, bounds: moved)])
        stabilizer.record([reading(1200, isPrice: true, bounds: moved)])

        #expect(stabilizer.items == [reading(1200, isPrice: true, bounds: moved)])
    }

    private func ramen(_ amount: Decimal, movedBy offset: CGFloat) -> DetectedItem {
        DetectedItem(
            id: id,
            lineID: id,
            transcript: "Ramen ¥\(amount)",
            tokenQuad: Quad(CGRect(x: 140 + offset, y: 80, width: 60, height: 30)),
            lineQuad: Quad(CGRect(x: offset, y: 80, width: 200, height: 30)),
            lineTextQuads: [Quad(CGRect(x: offset, y: 80, width: 100, height: 30))],
            rowNeighbourCenter: CGPoint(x: 40 + offset, y: 95),
            perUnitSuffix: nil,
            conversion: .init(amount: amount, converted: amount / 150, isPrice: true)
        )
    }

    @Test func aMovingLabelTakesItsPlaceFromTheNewestReadingAndItsAmountFromTheVote() throws {
        var stabilizer = LiveDetectionStabilizer()
        for offset in [0, 4, -3] as [CGFloat] {
            stabilizer.record([ramen(980, movedBy: offset)])
        }

        stabilizer.record([ramen(989, movedBy: 12)])

        let shown = try #require(stabilizer.items.first)
        let newest = ramen(989, movedBy: 12)
        #expect(shown.conversion.amount == 980)
        #expect(shown.tokenQuad == newest.tokenQuad)
        #expect(shown.lineQuad == newest.lineQuad)
        #expect(shown.lineTextQuads == newest.lineTextQuads)
        #expect(shown.rowNeighbourCenter == newest.rowNeighbourCenter)
    }

    @Test func movingTheLabelsMovesShownAndLingeringLabelsAlike() throws {
        var stabilizer = LiveDetectionStabilizer()
        let lingering = DetectedItem(
            id: UUID(),
            transcript: "¥450",
            bounds: CGRect(x: 10, y: 300, width: 50, height: 20),
            conversion: .init(amount: 450, converted: 3, isPrice: true)
        )
        stabilizer.record([ramen(980, movedBy: 0), lingering])
        stabilizer.record([ramen(980, movedBy: 0)])

        stabilizer.transform(by: CGAffineTransform(translationX: 10, y: -5))

        let shown = try #require(stabilizer.items.first { $0.id == id })
        let moved = try #require(stabilizer.items.first { $0.id == lingering.id })
        #expect(shown.tokenQuad.boundingBox == CGRect(x: 150, y: 75, width: 60, height: 30))
        #expect(shown.lineQuad.boundingBox == CGRect(x: 10, y: 75, width: 200, height: 30))
        #expect(shown.lineTextQuads.map(\.boundingBox) == [CGRect(x: 10, y: 75, width: 100, height: 30)])
        #expect(shown.rowNeighbourCenter == CGPoint(x: 50, y: 90))
        #expect(moved.bounds == CGRect(x: 20, y: 295, width: 50, height: 20))
    }

    @Test func onlyTheLastFiveReadingsVote() {
        var stabilizer = LiveDetectionStabilizer()
        for _ in 0..<5 {
            stabilizer.record([reading(1200, isPrice: true)])
        }

        for _ in 0..<3 {
            stabilizer.record([reading(1200, isPrice: false)])
        }

        #expect(stabilizer.items.first?.conversion.isPrice == false)
    }

    @Test func aVanishedItemLingersUntilItsWindowExpires() throws {
        var stabilizer = LiveDetectionStabilizer()
        stabilizer.record([reading(1200, isPrice: true)])

        let opened = stabilizer.record([])
        let window = try #require(opened)
        #expect(stabilizer.items == [reading(1200, isPrice: true)])

        stabilizer.expireLingering(through: window)
        #expect(stabilizer.items.isEmpty)
    }

    @Test func anEarlierWindowCannotExpireAReturningItem() throws {
        var stabilizer = LiveDetectionStabilizer()
        stabilizer.record([reading(1200, isPrice: true)])
        let firstOpened = stabilizer.record([])
        stabilizer.record([reading(1200, isPrice: true)])
        let secondOpened = stabilizer.record([])
        let firstWindow = try #require(firstOpened)
        let secondWindow = try #require(secondOpened)

        stabilizer.expireLingering(through: firstWindow)
        #expect(stabilizer.items.count == 1)

        stabilizer.expireLingering(through: secondWindow)
        #expect(stabilizer.items.isEmpty)
    }

    @Test func aFrameWithEveryItemPresentOpensNoWindow() {
        var stabilizer = LiveDetectionStabilizer()
        stabilizer.record([reading(1200, isPrice: true)])

        let opened = stabilizer.record([reading(1200, isPrice: true)])

        #expect(opened == nil)
    }

    @Test func resetForgetsEveryReading() {
        var stabilizer = LiveDetectionStabilizer()
        for _ in 0..<3 {
            stabilizer.record([reading(1200, isPrice: true)])
        }

        stabilizer.reset()
        stabilizer.record([reading(1200, isPrice: false)])

        #expect(stabilizer.items.first?.conversion.isPrice == false)
    }
}
