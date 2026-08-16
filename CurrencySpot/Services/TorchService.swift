import AVFoundation

protocol TorchService: Sendable {
    func setTorch(enabled: Bool) -> Bool
}

// Must lock `userPreferredCamera` specifically: locking any other device sharing
// the same hardware freezes DataScanner's remote session (Apple Developer Forums
// thread 717017).
struct AVTorchService: TorchService {
    func setTorch(enabled: Bool) -> Bool {
        guard let device = AVCaptureDevice.userPreferredCamera,
              device.hasTorch, device.isTorchAvailable
        else { return false }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if enabled {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            return enabled
        } catch {
            return false
        }
    }
}
