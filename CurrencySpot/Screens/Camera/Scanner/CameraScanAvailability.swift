//
//  CameraScanAvailability.swift
//  CurrencySpot
//

import VisionKit

/// Gate for the Camera tab. Per the camera plan, unsupported devices hide the tab entirely.
enum CameraScanAvailability {
    static var isSupported: Bool {
        #if DEBUG && targetEnvironment(simulator)
        // DataScanner needs a Neural Engine and a camera, so the simulator reports
        // unsupported. Show the tab anyway in debug builds so the photo-import path
        // and the permission states stay testable during development.
        return true
        #else
        return DataScannerViewController.isSupported
        #endif
    }
}
