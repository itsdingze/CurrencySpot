import CoreGraphics

struct AspectFitMapping {
    let imageSize: CGSize
    let viewSize: CGSize

    func viewRect(for imageRect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let origin = viewPoint(imageRect.origin)
        return CGRect(x: origin.x, y: origin.y, width: imageRect.width * scale, height: imageRect.height * scale)
    }

    func viewPoint(_ imagePoint: CGPoint) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        return CGPoint(
            x: imagePoint.x * scale + (viewSize.width - imageSize.width * scale) / 2,
            y: imagePoint.y * scale + (viewSize.height - imageSize.height * scale) / 2
        )
    }

    private var scale: CGFloat {
        min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    }
}
