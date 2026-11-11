import CoreGraphics

nonisolated struct CameraZoom: Equatable {
    private static let ratioCap: CGFloat = 10
    private static let accessibilityStep: CGFloat = 2

    private(set) var ratio: CGFloat = 1
    private(set) var maximumRatio: CGFloat
    private var pinchStartRatio: CGFloat?

    init(deviceMaximumRatio: CGFloat) {
        maximumRatio = min(max(deviceMaximumRatio, 1), Self.ratioCap)
    }

    mutating func pinch(by magnification: CGFloat) {
        let start = pinchStartRatio ?? ratio
        pinchStartRatio = start
        ratio = clamped(start * magnification)
    }

    mutating func endPinch() {
        pinchStartRatio = nil
    }

    mutating func zoomIn() {
        ratio = clamped(ratio * Self.accessibilityStep)
    }

    mutating func zoomOut() {
        ratio = clamped(ratio / Self.accessibilityStep)
    }

    mutating func reset(deviceMaximumRatio: CGFloat) {
        self = CameraZoom(deviceMaximumRatio: deviceMaximumRatio)
    }

    private func clamped(_ ratio: CGFloat) -> CGFloat {
        min(max(ratio, 1), maximumRatio)
    }
}
