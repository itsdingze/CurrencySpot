#if DEBUG

    import Foundation
    import UIKit

    nonisolated struct FakeCameraFrame: Sendable {
        private static let launchArgument = "CameraFakeFrame"
        private static let frameWidth: CGFloat = 1080

        let image: UIImage
        let frame: CapturedFrame

        static func fromLaunchArguments() -> FakeCameraFrame? {
            guard let path = UserDefaults.standard.string(forKey: launchArgument),
                  let source = UIImage(contentsOfFile: path),
                  source.size.width > 0
            else { return nil }
            let size = CGSize(width: frameWidth, height: (source.size.height * frameWidth / source.size.width).rounded())
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                source.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let cgImage = image.cgImage, let frame = CapturedFrame.rendering(cgImage) else { return nil }
            return FakeCameraFrame(image: image, frame: frame)
        }
    }

#endif
