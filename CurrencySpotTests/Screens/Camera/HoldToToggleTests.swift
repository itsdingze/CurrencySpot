import CoreGraphics
import Testing
@testable import CurrencySpot

struct HoldToToggleTests {
    private let button = CGRect(x: 0, y: 0, width: 44, height: 44)
    private let center = CGPoint(x: 22, y: 22)

    @Test func holdingPastTheBuzzSwitchesOnRelease() {
        var press = HoldToToggle()

        press.touch(at: center, in: button)
        let buzzes = press.holdElapsed()
        let switches = press.release()

        #expect(buzzes)
        #expect(switches)
    }

    @Test func slidingOffAfterTheBuzzCancels() {
        var press = HoldToToggle()

        press.touch(at: center, in: button)
        _ = press.holdElapsed()
        press.touch(at: CGPoint(x: 200, y: 22), in: button)

        #expect(press.release() == false)
    }

    @Test func slidingJustPastTheButtonsEdgeCancels() {
        var press = HoldToToggle()

        press.touch(at: center, in: button)
        _ = press.holdElapsed()
        press.touch(at: CGPoint(x: 47, y: 22), in: button)

        #expect(press.release() == false)
    }

    @Test func slidingIntoTheCornerOutsideTheRoundButtonCancels() {
        var press = HoldToToggle()

        press.touch(at: center, in: button)
        _ = press.holdElapsed()
        press.touch(at: CGPoint(x: 42, y: 42), in: button)

        #expect(press.release() == false)
    }

    @Test func slidingOffBeforeTheBuzzCancelsTheBuzz() {
        var press = HoldToToggle()

        press.touch(at: center, in: button)
        press.touch(at: CGPoint(x: 22, y: -200), in: button)

        #expect(press.holdElapsed() == false)
        #expect(press.release() == false)
    }

    @Test func aQuickTapDoesNothing() {
        var press = HoldToToggle()

        press.touch(at: center, in: button)

        #expect(press.release() == false)
    }
}
