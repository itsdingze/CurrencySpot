import CoreGraphics

nonisolated enum AppIconArtwork {
    private static let cornerRadiusRatio: CGFloat = 0.25

    static func cornerRadius(forSide side: CGFloat) -> CGFloat {
        side * cornerRadiusRatio
    }
}
