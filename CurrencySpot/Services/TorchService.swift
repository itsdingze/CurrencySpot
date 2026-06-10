//
//  TorchService.swift
//  CurrencySpot
//

import AVFoundation

protocol TorchService: Sendable {
    /// Attempts to set the torch; returns the resulting state.
    func setTorch(enabled: Bool) -> Bool
}

/// Toggles the torch on the camera DataScanner is actually streaming from.
/// `userPreferredCamera` resolves to the in-use (virtual) device; locking any
/// other device sharing the same hardware freezes the scanner's remote session
/// (see Apple Developer Forums thread 717017).
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
