@testable import CurrencySpot
import CoreGraphics
import Testing

@Suite("FingerDemoFrame Tests")
struct FingerDemoFrameTests {
    private let positions: [CGFloat] = [10, 60, 110]
    private let height: CGFloat = 150

    @Test("at a whole-number progress the fingertip sits over that point")
    func fingertipOverPoint() {
        let frame = FingerDemoFrame(progress: 1, opacity: 1, touch: 1)

        #expect(frame.fingertip(alongX: positions, atHeight: height) == CGPoint(x: positions[1], y: height))
    }

    @Test("between two points the fingertip travels between them")
    func fingertipBetweenPoints() throws {
        let frame = FingerDemoFrame(progress: 1.5, opacity: 1, touch: 1)

        let tip = try #require(frame.fingertip(alongX: positions, atHeight: height))

        #expect(tip.x > positions[1] && tip.x < positions[2])
    }

    @Test("the drag is a straight horizontal motion at a fixed height")
    func dragIsStraightAndHorizontal() throws {
        for step in 0 ... 40 {
            let frame = FingerDemoFrame(progress: Double(step) / 20, opacity: 1, touch: 1)

            let tip = try #require(frame.fingertip(alongX: positions, atHeight: height))

            #expect(tip.y == height)
        }
    }

    @Test("a pressed finger selects the point nearest the fingertip", arguments: [
        (1.4, 1), (1.6, 2), (0.0, 0),
    ])
    func pressedFingerSelectsNearestPoint(progress: Double, expectedIndex: Int) {
        let frame = FingerDemoFrame(progress: progress, opacity: 1, touch: 1)

        #expect(frame.selectedIndex(pointCount: positions.count) == expectedIndex)
    }

    @Test("while dragging, the selection is always the point nearest the fingertip")
    func selectionTracksFingertipThroughoutDrag() throws {
        for step in 0 ... 40 {
            let frame = FingerDemoFrame(progress: Double(step) / 20, opacity: 1, touch: 1)
            let tip = try #require(frame.fingertip(alongX: positions, atHeight: height))
            let selected = try #require(frame.selectedIndex(pointCount: positions.count))

            let nearest = try #require(positions.indices.min { abs(positions[$0] - tip.x) < abs(positions[$1] - tip.x) })
            #expect(abs(positions[selected] - tip.x) == abs(positions[nearest] - tip.x))
        }
    }

    @Test("progress past either end clamps to the first or last point", arguments: [
        (-1.0, 0), (7.0, 2),
    ])
    func progressClampsToEnds(progress: Double, expectedIndex: Int) {
        let frame = FingerDemoFrame(progress: progress, opacity: 1, touch: 1)

        #expect(frame.fingertip(alongX: positions, atHeight: height)?.x == positions[expectedIndex])
        #expect(frame.selectedIndex(pointCount: positions.count) == expectedIndex)
    }

    @Test("a pressed finger is drawn smaller than a hovering one")
    func pressedFingerIsSmaller() {
        let hovering = FingerDemoFrame(progress: 0, opacity: 1, touch: 0)
        let pressed = FingerDemoFrame(progress: 0, opacity: 1, touch: 1)

        #expect(pressed.scale < hovering.scale)
    }

    @Test("a hovering finger selects nothing")
    func hoveringFingerSelectsNothing() {
        let frame = FingerDemoFrame(progress: 1, opacity: 0.5, touch: 0)

        #expect(frame.selectedIndex(pointCount: positions.count) == nil)
    }
}
