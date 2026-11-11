import CoreGraphics
import Testing
@testable import CurrencySpot

struct CameraZoomFactorsTests {
    @Test("a single wide camera's 1x is device factor 1")
    func singleCameraStartsAtFactorOne() {
        #expect(CameraZoomFactors.zoomFactor(forRatio: 1, switchOverFactors: [], minimum: 1, maximum: 16) == 1)
        #expect(CameraZoomFactors.zoomFactor(forRatio: 3, switchOverFactors: [], minimum: 1, maximum: 16) == 3)
    }

    @Test("a dual wide camera's 1x is its switch-over to the wide lens")
    func dualWideStartsAtItsSwitchOver() {
        #expect(CameraZoomFactors.zoomFactor(forRatio: 1, switchOverFactors: [2], minimum: 1, maximum: 16) == 2)
        #expect(CameraZoomFactors.zoomFactor(forRatio: 2.5, switchOverFactors: [2], minimum: 1, maximum: 16) == 5)
    }

    @Test("a triple camera's 1x is factor 2, not its telephoto switch-over")
    func tripleCameraStartsAtTheWideLens() {
        #expect(CameraZoomFactors.zoomFactor(forRatio: 1, switchOverFactors: [2, 6], minimum: 1, maximum: 30) == 2)
        #expect(CameraZoomFactors.zoomFactor(forRatio: 3, switchOverFactors: [2, 6], minimum: 1, maximum: 30) == 6)
    }

    @Test("the device factor stays within what the device allows")
    func factorStaysWithinTheDeviceRange() {
        #expect(CameraZoomFactors.zoomFactor(forRatio: 10, switchOverFactors: [2, 6], minimum: 1, maximum: 15) == 15)
        #expect(CameraZoomFactors.zoomFactor(forRatio: 0.25, switchOverFactors: [2, 6], minimum: 1, maximum: 15) == 1)
    }

    @Test("the widest zoom ratio counts from the 1x lens")
    func maximumRatioCountsFromOneX() {
        #expect(CameraZoomFactors.maximumRatio(switchOverFactors: [2, 6], maximumFactor: 30) == 15)
        #expect(CameraZoomFactors.maximumRatio(switchOverFactors: [2], maximumFactor: 2) == 1)
        #expect(CameraZoomFactors.maximumRatio(switchOverFactors: [], maximumFactor: 16) == 16)
    }
}
