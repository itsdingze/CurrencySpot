import CoreGraphics
import Testing
@testable import CurrencySpot

struct CameraZoomTests {
    @Test("a pinch scales the zoom it started from")
    func pinchScalesFromItsStart() {
        var zoom = CameraZoom(deviceMaximumRatio: 10)

        zoom.pinch(by: 2)
        zoom.pinch(by: 3)
        #expect(zoom.ratio == 3)

        zoom.endPinch()
        zoom.pinch(by: 1.5)
        #expect(zoom.ratio == 4.5)
    }

    @Test("zoom never goes wider than the 1x lens")
    func staysAtOrAboveOneX() {
        var zoom = CameraZoom(deviceMaximumRatio: 10)

        zoom.pinch(by: 0.5)

        #expect(zoom.ratio == 1)
    }

    @Test("zoom stops at the device's maximum")
    func stopsAtTheDeviceMaximum() {
        var zoom = CameraZoom(deviceMaximumRatio: 6)

        zoom.pinch(by: 20)

        #expect(zoom.ratio == 6)
    }

    @Test("zoom stops at 10x even when the device goes further")
    func stopsAtTenX() {
        var zoom = CameraZoom(deviceMaximumRatio: 25)

        zoom.pinch(by: 20)

        #expect(zoom.ratio == 10)
    }

    @Test("restarting the camera returns to 1x")
    func restartReturnsToOneX() {
        var zoom = CameraZoom(deviceMaximumRatio: 10)
        zoom.pinch(by: 3)

        zoom.reset(deviceMaximumRatio: 10)

        #expect(zoom.ratio == 1)
    }

    @Test("VoiceOver zoom steps in and out within the range")
    func accessibilityStepsStayInRange() {
        var zoom = CameraZoom(deviceMaximumRatio: 10)

        zoom.zoomIn()
        let stepped = zoom.ratio
        for _ in 0 ..< 20 { zoom.zoomIn() }
        let top = zoom.ratio
        zoom.zoomOut()
        let belowTop = zoom.ratio
        for _ in 0 ..< 20 { zoom.zoomOut() }

        #expect(stepped > 1)
        #expect(top == 10)
        #expect(belowTop < 10)
        #expect(zoom.ratio == 1)
    }
}
