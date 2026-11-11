import Accelerate
import CoreGraphics
import CoreVideo
import Vision

nonisolated struct FrameMotionEstimator {
    private static let downscale = 4

    private var previous: CVPixelBuffer?

    mutating func displacement(to frame: CVPixelBuffer) -> CGPoint? {
        guard let current = Self.downscaledLuma(of: frame) else { return nil }
        defer { previous = current }
        guard let previous else { return nil }
        return Self.displacement(from: previous, to: current)
    }

    mutating func reset() {
        previous = nil
    }

    private static func displacement(from previous: CVPixelBuffer, to current: CVPixelBuffer) -> CGPoint? {
        let request = VNTranslationalImageRegistrationRequest(targetedCVPixelBuffer: current)
        do {
            try VNImageRequestHandler(cvPixelBuffer: previous).perform([request])
        } catch {
            return nil
        }
        guard let transform = request.results?.first?.alignmentTransform else { return nil }
        let scale = CGFloat(downscale)
        return CGPoint(x: -transform.tx * scale, y: transform.ty * scale)
    }

    private static func downscaledLuma(of frame: CVPixelBuffer) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }
        guard CVPixelBufferGetPlaneCount(frame) >= 2,
              let sourceBase = CVPixelBufferGetBaseAddressOfPlane(frame, 0)
        else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(frame, 0)
        let height = CVPixelBufferGetHeightOfPlane(frame, 0)
        var source = vImage_Buffer(
            data: sourceBase,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: CVPixelBufferGetBytesPerRowOfPlane(frame, 0)
        )
        guard let output = makeLumaBuffer(width: width / downscale, height: height / downscale) else { return nil }
        CVPixelBufferLockBaseAddress(output, [])
        defer { CVPixelBufferUnlockBaseAddress(output, []) }
        guard let outputBase = CVPixelBufferGetBaseAddress(output) else { return nil }
        var destination = vImage_Buffer(
            data: outputBase,
            height: vImagePixelCount(height / downscale),
            width: vImagePixelCount(width / downscale),
            rowBytes: CVPixelBufferGetBytesPerRow(output)
        )
        guard vImageScale_Planar8(&source, &destination, nil, vImage_Flags(kvImageNoFlags)) == kvImageNoError else { return nil }
        return output
    }

    private static func makeLumaBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, attributes, &buffer)
        return status == kCVReturnSuccess ? buffer : nil
    }
}
