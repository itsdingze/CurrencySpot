//
//  AspectFitMapping.swift
//  CurrencySpot
//

import CoreGraphics

/// Maps rects from image-pixel space into the coordinate space of a view
/// displaying that image aspect-fit (scaled to fit, centered).
struct AspectFitMapping {
    let imageSize: CGSize
    let viewSize: CGSize

    func viewRect(for imageRect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let offsetX = (viewSize.width - imageSize.width * scale) / 2
        let offsetY = (viewSize.height - imageSize.height * scale) / 2
        return CGRect(
            x: imageRect.minX * scale + offsetX,
            y: imageRect.minY * scale + offsetY,
            width: imageRect.width * scale,
            height: imageRect.height * scale
        )
    }
}
