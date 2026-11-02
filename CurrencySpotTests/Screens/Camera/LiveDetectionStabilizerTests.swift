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

    @Test func boundsFollowTheLatestFrame() {
        var stabilizer = LiveDetectionStabilizer()
        let moved = CGRect(x: 40, y: 80, width: 100, height: 30)
        stabilizer.record([reading(1200, isPrice: true)])

        stabilizer.record([reading(1200, isPrice: false, bounds: moved)])

        #expect(stabilizer.items == [reading(1200, isPrice: true, bounds: moved)])
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
