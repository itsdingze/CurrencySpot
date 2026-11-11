import AVFoundation
import Testing
@testable import CurrencySpot

struct BackCameraChoiceTests {
    @Test("the triple camera wins so close focus can switch lenses")
    func prefersTheTripleCamera() {
        let available: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInDualWideCamera, .builtInTripleCamera]

        #expect(BackCameraChoice.preferred(among: available) == .builtInTripleCamera)
    }

    @Test("without a triple camera the dual wide camera wins")
    func fallsBackToTheDualWideCamera() {
        let available: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInDualWideCamera]

        #expect(BackCameraChoice.preferred(among: available) == .builtInDualWideCamera)
    }

    @Test("a phone with one back camera uses its wide angle camera")
    func fallsBackToTheWideAngleCamera() {
        let available: [AVCaptureDevice.DeviceType] = [.builtInTelephotoCamera, .builtInWideAngleCamera]

        #expect(BackCameraChoice.preferred(among: available) == .builtInWideAngleCamera)
    }

    @Test("no back camera means no choice")
    func noBackCameraMeansNoChoice() {
        #expect(BackCameraChoice.preferred(among: []) == nil)
    }
}
