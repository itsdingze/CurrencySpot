import AVFoundation

nonisolated enum BackCameraChoice {
    private static let preference: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInWideAngleCamera,
    ]

    static func preferred(among available: [AVCaptureDevice.DeviceType]) -> AVCaptureDevice.DeviceType? {
        preference.first(where: available.contains)
    }

    static func device() -> AVCaptureDevice? {
        let devices = backDevices
        guard let type = preferred(among: devices.map(\.deviceType)) else { return nil }
        return devices.first { $0.deviceType == type }
    }

    static var availableTypes: [AVCaptureDevice.DeviceType] {
        backDevices.map(\.deviceType)
    }

    private static var backDevices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: preference, mediaType: .video, position: .back).devices
    }
}
