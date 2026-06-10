//
//  CameraPermissionService.swift
//  CurrencySpot
//

import AVFoundation

enum CameraAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
}

protocol CameraPermissionService: Sendable {
    func currentStatus() -> CameraAuthorizationStatus
    func requestAccess() async -> Bool
}

struct AVCameraPermissionService: CameraPermissionService {
    func currentStatus() -> CameraAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
