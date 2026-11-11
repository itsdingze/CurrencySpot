import CoreGraphics

nonisolated struct RecognitionRegion: Equatable, Sendable {
    private static let minimumBandedImageHeight: CGFloat = 1350
    private static let bandCount = 3
    private static let bandOverlapFraction: CGFloat = 0.15
    private static let cutEdgeToleranceFraction: CGFloat = 0.02
    private static let smallestReadableTextHeight: CGFloat = 16

    let rect: CGRect
    private let isCutAtTop: Bool
    private let isCutAtBottom: Bool
    private let minimumLineHeight: CGFloat

    var minimumTextHeightFraction: Float {
        Float(Self.smallestReadableTextHeight / rect.height)
    }

    static func whole(_ imageSize: CGSize) -> RecognitionRegion {
        RecognitionRegion(rect: CGRect(origin: .zero, size: imageSize), isCutAtTop: false, isCutAtBottom: false, minimumLineHeight: 0)
    }

    static func regions(covering imageSize: CGSize) -> [RecognitionRegion] {
        let frame = CGRect(origin: .zero, size: imageSize)
        guard imageSize.height >= minimumBandedImageHeight else {
            return [whole(imageSize)]
        }
        let bandHeight = (imageSize.height / CGFloat(bandCount) * (1 + bandOverlapFraction)).rounded()
        let lastBandTop = imageSize.height - bandHeight
        let bandTops = (0 ..< bandCount).map { (lastBandTop * CGFloat($0) / CGFloat(bandCount - 1)).rounded() }
        let bands = bandTops.enumerated().map { index, top in
            RecognitionRegion(
                rect: CGRect(x: 0, y: top, width: imageSize.width, height: bandHeight),
                isCutAtTop: index > 0,
                isCutAtBottom: index < bandCount - 1,
                minimumLineHeight: 0
            )
        }
        let overlap = bandHeight - bandTops[1]
        let shortestLineEveryBandMayCut = overlap - 2 * bandHeight * cutEdgeToleranceFraction
        let wholeFrame = RecognitionRegion(rect: frame, isCutAtTop: false, isCutAtBottom: false, minimumLineHeight: shortestLineEveryBandMayCut)
        return bands + [wholeFrame]
    }

    func keeps(_ lineBounds: CGRect) -> Bool {
        let tolerance = rect.height * Self.cutEdgeToleranceFraction
        if isCutAtTop, lineBounds.minY <= rect.minY + tolerance { return false }
        if isCutAtBottom, lineBounds.maxY >= rect.maxY - tolerance { return false }
        return lineBounds.height >= minimumLineHeight
    }
}
