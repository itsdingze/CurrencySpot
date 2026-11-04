import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

struct RowSlopeTests {
    private let degrees = CGFloat.pi / 180
    private let level = PageAxes(angle: 0)

    private func box(centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat = 20) -> Quad {
        Quad(CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height))
    }

    @Test func levelBoxesAlongASlopedRowGiveTheRowsSlope() throws {
        let name = box(centerX: 100, centerY: 300, width: 80)
        let price = box(centerX: 300, centerY: 300 - 200 * tan(4 * degrees), width: 60)
        let rowAbove = box(centerX: 100, centerY: 260, width: 80)

        let neighbour = try #require(RowSlope.neighbourCenter(leftOf: price, among: [rowAbove, name, price], on: level))
        let sample = try #require(RowSlope.sample(of: price, rowNeighbourCenter: neighbour))

        #expect(neighbour == name.center)
        #expect(abs(sample - -4 * degrees) < 0.0001)
    }

    @Test func onATurnedPageTheNeighbourIsTheNameOnThePricesOwnRow() {
        let turn = -20 * degrees
        let name = turned(box(centerX: 100, centerY: 0, width: 80), by: turn)
        let nameTwoRowsUpAtThePricesHeight = turned(box(centerX: 100, centerY: -80, width: 80), by: turn)
        let price = turned(box(centerX: 300, centerY: 0, width: 60), by: turn)
        let lines = [nameTwoRowsUpAtThePricesHeight, name, price]

        #expect(RowSlope.neighbourCenter(leftOf: price, among: lines, on: RowSlope.page(of: lines)) == name.center)
    }

    private func turned(_ quad: Quad, by angle: CGFloat) -> Quad {
        quad.mapped { CGPoint(x: $0.x * cos(angle) - $0.y * sin(angle), y: $0.x * sin(angle) + $0.y * cos(angle)) }
    }

    @Test func nearestBoxToTheLeftIsTheNeighbour() {
        let far = box(centerX: 60, centerY: 300, width: 40)
        let near = box(centerX: 180, centerY: 300, width: 60)
        let price = box(centerX: 300, centerY: 300, width: 60)

        #expect(RowSlope.neighbourCenter(leftOf: price, among: [far, near, price], on: level) == near.center)
    }

    @Test func boxOverlappingThePriceIsNotALeftNeighbour() {
        let line = box(centerX: 150, centerY: 300, width: 280)
        let price = box(centerX: 260, centerY: 300, width: 60)

        #expect(RowSlope.neighbourCenter(leftOf: price, among: [line, price], on: level) == nil)
    }

    @Test func wideLineWithoutANeighbourGivesItsOwnAngle() throws {
        let line = Quad(CGRect(x: 0, y: 0, width: 200, height: 20)).mapped { point in
            CGPoint(x: point.x * cos(-8 * degrees) - point.y * sin(-8 * degrees), y: point.x * sin(-8 * degrees) + point.y * cos(-8 * degrees))
        }

        let sample = try #require(RowSlope.sample(of: line, rowNeighbourCenter: nil))

        #expect(abs(sample - -8 * degrees) < 0.0001)
    }

    @Test func shortLineWithoutANeighbourGivesNoSample() {
        let line = box(centerX: 300, centerY: 300, width: 60)

        #expect(RowSlope.sample(of: line, rowNeighbourCenter: nil) == nil)
    }
}
