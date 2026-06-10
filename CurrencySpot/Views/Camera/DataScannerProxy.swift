//
//  DataScannerProxy.swift
//  CurrencySpot
//

import UIKit

/// Hands the hosting SwiftUI view a line to the scanner for imperative
/// one-shot calls (photo capture).
@MainActor
final class DataScannerProxy {
    weak var host: ScannerHostController?

    /// Returns nil when no scanner is attached (e.g. simulator);
    /// throws when the scanner exists but the capture fails.
    func capturePhoto() async throws -> UIImage? {
        guard let scanner = host?.scanner else { return nil }
        return try await scanner.capturePhoto()
    }

    /// Restarts scanning if the system tore the session down behind our back
    /// (e.g. after backgrounding, where viewDidAppear never re-fires).
    func syncScanning() {
        host?.syncScanning()
    }
}
