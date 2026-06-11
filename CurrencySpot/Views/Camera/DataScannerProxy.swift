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
    /// `capturePhoto()` keeps the preview's zoom but returns the sensor's
    /// full aspect ratio — center-crop to the preview's aspect so the frozen
    /// frame is framed exactly like the live feed.
    func capturePhoto() async throws -> UIImage? {
        guard let host else { return nil }
        let photo = try await host.scanner.capturePhoto()
        let aspectRatio = host.view.bounds.aspectRatio
        return await Self.crop(photo, toAspectRatio: aspectRatio)
    }

    /// Redrawing a full-resolution photo takes tens of milliseconds —
    /// keep it off the main actor.
    private nonisolated static func crop(_ photo: UIImage, toAspectRatio aspectRatio: CGFloat?) async -> UIImage {
        photo.croppedToPreview(aspectRatio: aspectRatio)
    }

    /// Restarts scanning if the system tore the session down behind our back
    /// (e.g. after backgrounding, where viewDidAppear never re-fires).
    func syncScanning() {
        host?.syncScanning()
    }
}

private extension CGRect {
    var aspectRatio: CGFloat? {
        height > 0 ? width / height : nil
    }
}

private extension UIImage {
    /// The region an aspect-filled preview of this image would show in a
    /// view with the given width-to-height ratio.
    func croppedToPreview(aspectRatio: CGFloat?) -> UIImage {
        guard let aspectRatio, size.width > 0, size.height > 0 else { return self }
        var visible = size
        if visible.width / visible.height > aspectRatio {
            visible.width = visible.height * aspectRatio
        } else {
            visible.height = visible.width / aspectRatio
        }
        guard visible != size else { return self }
        let origin = CGPoint(x: (size.width - visible.width) / 2, y: (size.height - visible.height) / 2)
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: visible, format: format).image { _ in
            draw(at: CGPoint(x: -origin.x, y: -origin.y))
        }
    }
}
