import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

struct LiveItemIdentitiesTests {
    private func item(at center: CGPoint, _ transcript: String = "680円", scannerID: UUID = UUID()) -> RecognizedTextItem {
        RecognizedTextItem(
            id: scannerID,
            transcript: transcript,
            bounds: CGRect(x: center.x - 25, y: center.y - 10, width: 50, height: 20)
        )
    }

    @Test func pricesSharingOneScannerIDGetTheirOwnIDs() {
        var identities = LiveItemIdentities()
        let shared = UUID()

        let frame = identities.identify([
            item(at: CGPoint(x: 100, y: 100), scannerID: shared),
            item(at: CGPoint(x: 100, y: 130), "580円", scannerID: shared),
        ])

        #expect(Set(frame.map(\.id)).count == 2)
    }

    @Test func aPriceThatMovesALittleKeepsItsID() throws {
        var identities = LiveItemIdentities()
        let first = try #require(identities.identify([item(at: CGPoint(x: 100, y: 100))]).first)

        let second = try #require(identities.identify([item(at: CGPoint(x: 104, y: 103))]).first)

        #expect(second.id == first.id)
    }

    @Test func aNewPriceGetsANewID() throws {
        var identities = LiveItemIdentities()
        let first = try #require(identities.identify([item(at: CGPoint(x: 100, y: 100))]).first)

        let frame = identities.identify([item(at: CGPoint(x: 100, y: 100)), item(at: CGPoint(x: 300, y: 400), "1,200円")])

        #expect(frame.map(\.id) == [first.id, frame[1].id])
        #expect(frame[1].id != first.id)
    }

    @Test func aPriceMissingForAFrameKeepsItsID() throws {
        var identities = LiveItemIdentities()
        let first = try #require(identities.identify([item(at: CGPoint(x: 100, y: 100))]).first)
        _ = identities.identify([])

        let back = try #require(identities.identify([item(at: CGPoint(x: 101, y: 100))]).first)

        #expect(back.id == first.id)
    }

    @Test func neighbouringPricesKeepTheirIDsWhenTheViewShifts() {
        var identities = LiveItemIdentities()
        let first = identities.identify([item(at: CGPoint(x: 100, y: 100)), item(at: CGPoint(x: 100, y: 126), "580円")])

        let shifted = identities.identify([item(at: CGPoint(x: 103, y: 108)), item(at: CGPoint(x: 103, y: 134), "580円")])

        #expect(shifted.map(\.id) == first.map(\.id))
    }

    @Test func neighbouringPricesKeepTheirIDsWhenTheViewShiftsAWholeRow() {
        var identities = LiveItemIdentities()
        let first = identities.identify([item(at: CGPoint(x: 100, y: 100)), item(at: CGPoint(x: 100, y: 126), "580円")])

        let shifted = identities.identify([item(at: CGPoint(x: 100, y: 126)), item(at: CGPoint(x: 100, y: 152), "580円")])

        #expect(shifted.map(\.id) == first.map(\.id))
    }
}
