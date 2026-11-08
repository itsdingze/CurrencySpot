import AVFoundation

enum CameraScanAvailability {
    static let isSupported: Bool = {
        #if DEBUG && targetEnvironment(simulator)
        return true
        #else
        return isSupported(availableBackCameras: BackCameraChoice.availableTypes)
        #endif
    }()

    static func isSupported(availableBackCameras: [AVCaptureDevice.DeviceType]) -> Bool {
        BackCameraChoice.preferred(among: availableBackCameras) != nil
    }
}
