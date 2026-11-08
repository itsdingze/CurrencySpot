import UIKit

nonisolated enum PreviewCrop {
    static func visibleRect(in photoSize: CGSize, videoAspectRatio: CGFloat?, previewAspectRatio: CGFloat?) -> CGRect {
        let photo = CGRect(origin: .zero, size: photoSize)
        return centered(centered(photo, toAspectRatio: videoAspectRatio), toAspectRatio: previewAspectRatio).integral
    }

    private static func centered(_ rect: CGRect, toAspectRatio aspectRatio: CGFloat?) -> CGRect {
        guard let aspectRatio, aspectRatio > 0, rect.width > 0, rect.height > 0 else { return rect }
        var size = rect.size
        if size.width / size.height > aspectRatio {
            size.width = size.height * aspectRatio
        } else {
            size.height = size.width / aspectRatio
        }
        return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }
}

nonisolated extension UIImage {
    func cropped(to rect: CGRect) -> UIImage {
        guard rect.size != size, rect.width > 0, rect.height > 0 else { return self }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            draw(at: CGPoint(x: -rect.minX, y: -rect.minY))
        }
    }
}
