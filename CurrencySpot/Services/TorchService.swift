import AVFoundation

protocol TorchService: Sendable {
    func setTorch(enabled: Bool) -> Bool
}

struct AVTorchService: TorchService {
    func setTorch(enabled: Bool) -> Bool {
        guard let device = BackCameraChoice.device(),
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
