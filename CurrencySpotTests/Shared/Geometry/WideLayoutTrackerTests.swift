import CoreGraphics
import Testing
@testable import CurrencySpot

struct WideLayoutTrackerTests {
    @Test("a screen wider than tall uses the wide layout, a taller one does not")
    func followsTheScreenShape() {
        var sideways = WideLayoutTracker()
        var upright = WideLayoutTracker()

        sideways.update(for: CGSize(width: 951, height: 669))
        upright.update(for: CGSize(width: 669, height: 835))

        #expect(sideways.isWide)
        #expect(!upright.isWide)
    }

    @Test("the keyboard shortening a tall screen keeps the tall layout")
    func keyboardKeepsTallLayout() {
        var tracker = WideLayoutTracker()
        tracker.update(for: CGSize(width: 669, height: 835))

        tracker.update(for: CGSize(width: 669, height: 519))

        #expect(!tracker.isWide)
    }

    @Test("turning upright with the keyboard open settles on the tall layout once the keyboard closes")
    func keyboardClosingRechecksLayout() {
        var tracker = WideLayoutTracker()
        tracker.update(for: CGSize(width: 951, height: 669))
        tracker.update(for: CGSize(width: 669, height: 519))

        tracker.update(for: CGSize(width: 669, height: 835))

        #expect(!tracker.isWide)
    }

    @Test("unfolding switches to the wide layout and closing switches back")
    func foldingSwitchesLayouts() {
        var tracker = WideLayoutTracker()
        tracker.update(for: CGSize(width: 466, height: 560))

        tracker.update(for: CGSize(width: 951, height: 553))
        let unfolded = tracker.isWide
        tracker.update(for: CGSize(width: 466, height: 560))

        #expect(unfolded)
        #expect(!tracker.isWide)
    }
}
