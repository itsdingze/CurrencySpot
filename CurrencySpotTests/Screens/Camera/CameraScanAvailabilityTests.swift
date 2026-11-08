import AVFoundation
import Testing
@testable import CurrencySpot

struct CameraScanAvailabilityTests {
    @Test("a phone with a back camera can scan")
    func backCameraMeansSupported() {
        #expect(CameraScanAvailability.isSupported(availableBackCameras: [.builtInWideAngleCamera]))
    }

    @Test("a device without a back camera can't scan")
    func noBackCameraMeansUnsupported() {
        #expect(!CameraScanAvailability.isSupported(availableBackCameras: []))
    }
}
