import CoreGraphics

nonisolated enum CameraZoomFactors {
    static func zoomFactor(forRatio ratio: CGFloat, switchOverFactors: [CGFloat], minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(oneXFactor(switchOverFactors: switchOverFactors) * ratio, minimum), maximum)
    }

    static func maximumRatio(switchOverFactors: [CGFloat], maximumFactor: CGFloat) -> CGFloat {
        maximumFactor / oneXFactor(switchOverFactors: switchOverFactors)
    }

    private static func oneXFactor(switchOverFactors: [CGFloat]) -> CGFloat {
        switchOverFactors.first ?? 1
    }
}
