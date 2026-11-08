import CoreGraphics

nonisolated struct AspectFillMapping: Equatable {
    let imageSize: CGSize
    let viewSize: CGSize

    func viewPoint(_ imagePoint: CGPoint) -> CGPoint {
        CGPoint(
            x: imagePoint.x * scale + (viewSize.width - imageSize.width * scale) / 2,
            y: imagePoint.y * scale + (viewSize.height - imageSize.height * scale) / 2
        )
    }

    func viewDistance(_ imageDistance: CGPoint) -> CGPoint {
        CGPoint(x: imageDistance.x * scale, y: imageDistance.y * scale)
    }

    private var scale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 0 }
        return max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    }
}
