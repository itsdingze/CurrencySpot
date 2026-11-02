import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CurrencySpot

struct PlateLayoutTests {
    private let frame = CGRect(x: 0, y: 0, width: 400, height: 800)
    private let lineID = UUID()

    private var plateLayout: PlateLayout {
        PlateLayout(frame: frame, measureText: { PlateTextWidth.of($0, fontSize: $1, legibilityWeight: .regular) })
    }

    private func price(
        _ token: CGRect,
        amount: Decimal = 980,
        line: Quad? = nil,
        lineText: [CGRect] = [],
        isPrice: Bool = true,
        id: UUID = UUID(),
        lineID: UUID? = nil
    ) -> DetectedItem {
        DetectedItem(
            id: id,
            lineID: lineID ?? self.lineID,
            transcript: "Ramen ¥980",
            tokenQuad: Quad(token),
            lineQuad: line ?? Quad(token),
            lineTextQuads: lineText.map(Quad.init),
            conversion: ScannedConversion(amount: amount, converted: 6.5, isPrice: isPrice)
        )
    }

    private func layout(_ items: [DetectedItem], text: String = "€6.50") -> PlateLayout.Result {
        var memory = PlateLayoutMemory(tracksFrames: false)
        return plateLayout.layout(items, text: { _ in text }, memory: &memory)
    }

    private func tiltedLine(degrees: CGFloat) -> Quad {
        let angle = degrees * .pi / 180
        return Quad(CGRect(x: 0, y: 0, width: 200, height: 20)).mapped { point in
            CGPoint(x: point.x * cos(angle) - point.y * sin(angle), y: point.x * sin(angle) + point.y * cos(angle))
        }
    }

    @Test func plateCoversItsWholeToken() throws {
        let token = CGRect(x: 100, y: 100, width: 80, height: 20)

        let plate = try #require(layout([price(token)]).plates.first)

        #expect(plate.visibleBounds.contains(token))
    }

    @Test func plateTextFitsInsideThePlate() throws {
        let text = "CA$1,234.56"
        let plate = try #require(layout([price(CGRect(x: 100, y: 100, width: 30, height: 20))], text: text).plates.first)

        #expect(plate.size.width >= PlateTextWidth.of(text, fontSize: plate.fontSize, legibilityWeight: .regular) + 10)
    }

    @Test func plateTextIsNeverSmallerThanTheMinimum() throws {
        let plate = try #require(layout([price(CGRect(x: 100, y: 100, width: 30, height: 4))]).plates.first)

        #expect(plate.fontSize >= 11)
    }

    @Test func widePlateGrowsAwayFromTheTextBesideIt() throws {
        let name = CGRect(x: 20, y: 100, width: 75, height: 20)
        let token = CGRect(x: 100, y: 100, width: 20, height: 20)

        let plate = try #require(layout([price(token, lineText: [name])], text: "€1,234.56").plates.first)

        #expect(plate.visibleBounds.minX >= name.maxX)
        #expect(plate.visibleBounds.maxX > token.maxX + 10)
    }

    @Test func plateAtTheEdgeSlidesBackInside() throws {
        let token = CGRect(x: 380, y: 100, width: 20, height: 20)

        let plate = try #require(layout([price(token)], text: "€1,234.56").plates.first)

        #expect(plate.visibleBounds.maxX <= frame.maxX)
    }

    @Test func plateFollowsATiltedPage() {
        let angle = 8 * CGFloat.pi / 180
        let tilted = Quad(CGRect(x: -100, y: -10, width: 200, height: 20)).mapped { point in
            CGPoint(x: 200 + point.x * cos(angle) - point.y * sin(angle), y: 200 + point.x * sin(angle) + point.y * cos(angle))
        }

        let result = layout([price(CGRect(x: 250, y: 205, width: 40, height: 20), line: tilted)])

        #expect(abs(result.angle - angle) < 0.001)
    }

    @Test func slightTiltIsDrawnLevel() {
        let angle = 1 * CGFloat.pi / 180
        let tilted = Quad(CGRect(x: 0, y: 0, width: 200, height: 20)).mapped { point in
            CGPoint(x: point.x * cos(angle) - point.y * sin(angle), y: point.x * sin(angle) + point.y * cos(angle))
        }

        let result = layout([price(CGRect(x: 150, y: 0, width: 40, height: 20), line: tilted)])

        #expect(result.angle == 0)
    }

    @Test func plateBelowAnotherInItsColumnKeepsBothOverhangs() throws {
        let upper = price(CGRect(x: 100, y: 94, width: 40, height: 12), lineID: UUID())
        let lower = price(CGRect(x: 100, y: 109, width: 40, height: 12), amount: 450, lineID: UUID())

        let plate = try #require(layout([upper, lower]).plates.last)

        #expect(plate.visibleBounds.minX <= 98.01)
        #expect(plate.visibleBounds.maxX >= 141.99)
    }

    @Test func heldLiveWidthNeverSpillsPastTheTextBesideIt() throws {
        var memory = PlateLayoutMemory(tracksFrames: true)
        let layout = plateLayout
        let id = UUID()
        let name = CGRect(x: 40, y: 100, width: 59, height: 12)
        func plate(nextWordAt start: CGFloat) -> PlateLayout.Plate? {
            let item = price(
                CGRect(x: 100, y: 100, width: 40, height: 12),
                lineText: [name, CGRect(x: start, y: 100, width: 30, height: 12)],
                id: id
            )
            return layout.layout([item], text: { _ in "€5" }, memory: &memory).plates.first
        }

        _ = plate(nextWordAt: 144)
        let squeezed = try #require(plate(nextWordAt: 142.5))

        #expect(squeezed.visibleBounds.minX >= name.maxX - 0.01)
        #expect(squeezed.visibleBounds.maxX <= 142.51)
    }

    @Test func livePageStaysLevelUntilItTiltsPastTwoDegrees() {
        var memory = PlateLayoutMemory(tracksFrames: true)
        let layout = plateLayout
        func angle(atDegrees degrees: CGFloat) -> CGFloat {
            let item = price(CGRect(x: 150, y: 0, width: 40, height: 20), line: tiltedLine(degrees: degrees))
            return layout.layout([item], text: { _ in "€6.50" }, memory: &memory).angle * 180 / .pi
        }

        let angles = [1.0, 1.8, 2.2, 1.8, 1.4].map { angle(atDegrees: $0) }

        #expect(angles.map { ($0 * 10).rounded() / 10 } == [0, 0, 2.2, 1.8, 0])
    }

    @Test func firstLiveFrameUsesTheExactSnap() {
        var memory = PlateLayoutMemory(tracksFrames: true)
        let item = price(CGRect(x: 150, y: 0, width: 40, height: 20), line: tiltedLine(degrees: 1.8))

        let result = plateLayout.layout([item], text: { _ in "€6.50" }, memory: &memory)

        #expect(abs(result.angle * 180 / .pi - 1.8) < 0.01)
    }

    @Test func stillPageSnapsLevelOnlyBelowOneAndAHalfDegrees() {
        let result = layout([price(CGRect(x: 150, y: 0, width: 40, height: 20), line: tiltedLine(degrees: 1.8))])

        #expect(abs(result.angle * 180 / .pi - 1.8) < 0.01)
    }

    @Test func aRepeatedReadingOfOnePriceShowsOnePlate() {
        let token = CGRect(x: 100, y: 100, width: 80, height: 20)

        let result = layout([price(token), price(token.offsetBy(dx: 3, dy: 1))])

        #expect(result.plates.count == 1)
    }

    @Test func bareNumberOutlineStaysOnItsNumber() throws {
        let token = CGRect(x: 100, y: 100, width: 40, height: 20)

        let outline = try #require(layout([price(token, isPrice: false)]).outlines.first)

        #expect(outline.center == CGPoint(x: token.midX, y: token.midY))
        #expect(outline.quad.boundingBox.contains(token))
    }

    @Test func lonePlateGetsAFullSizeTouchTarget() throws {
        let plate = try #require(layout([price(CGRect(x: 100, y: 100, width: 30, height: 12))]).plates.first)

        #expect(plate.hitTarget.width >= 44)
        #expect(plate.hitTarget.height >= 44)
        #expect(plate.hitTarget.contains(plate.visibleBounds))
    }

    @Test func stackedPlatesSplitTheirTouchTargets() throws {
        let upper = price(CGRect(x: 100, y: 100, width: 60, height: 14))
        let lower = price(CGRect(x: 100, y: 120, width: 60, height: 14), amount: 450)

        let result = layout([upper, lower])

        let first = try #require(result.plates.first)
        let second = try #require(result.plates.last)
        #expect(first.hitTarget.intersection(second.hitTarget).height <= 0.001)
        #expect(first.hitTarget.contains(first.visibleBounds))
        #expect(second.hitTarget.contains(second.visibleBounds))
        #expect(first.visibleBounds.maxY <= second.visibleBounds.minY)
    }

    @Test(arguments: [11, 20, 28] as [CGFloat], [LegibilityWeight.regular, .bold])
    func measuredWidthCoversSwiftUIText(fontSize: CGFloat, legibilityWeight: LegibilityWeight) {
        let text = "CA$1,234.56"
        let rendered = UIHostingController(
            rootView: Text(verbatim: text)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .fixedSize()
                .environment(\.legibilityWeight, legibilityWeight)
        ).sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))

        #expect(PlateTextWidth.of(text, fontSize: fontSize, legibilityWeight: legibilityWeight) >= rendered.width)
    }
}
