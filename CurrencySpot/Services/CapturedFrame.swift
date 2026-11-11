import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo

nonisolated struct CapturedFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let presentationTime: CMTime

    var size: CGSize {
        CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
    }

    #if DEBUG
    static func rendering(_ image: CGImage, presentationTime: CMTime = .zero) -> CapturedFrame? {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            image.width,
            image.height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attributes,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { return nil }
        CIContext().render(CIImage(cgImage: image), to: buffer)
        return CapturedFrame(pixelBuffer: buffer, presentationTime: presentationTime)
    }
    #endif
}
