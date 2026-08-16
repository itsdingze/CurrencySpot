import UIKit

final class DataScannerProxy {
    weak var host: ScannerHostController?

    func capturePhoto() async throws -> UIImage? {
        guard let host else { return nil }
        let photo = try await host.scanner.capturePhoto()
        let aspectRatio = host.view.bounds.aspectRatio
        return await Self.crop(photo, toAspectRatio: aspectRatio)
    }

    @concurrent
    private nonisolated static func crop(_ photo: UIImage, toAspectRatio aspectRatio: CGFloat?) async -> UIImage {
        photo.croppedToPreview(aspectRatio: aspectRatio)
    }

    func syncScanning() {
        host?.syncScanning()
    }
}

private nonisolated extension CGRect {
    var aspectRatio: CGFloat? {
        height > 0 ? width / height : nil
    }
}

private nonisolated extension UIImage {
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
