import AVFoundation
import SwiftUI
import UIKit

struct LiveCameraPreviewView: View {
    let preview: LiveCameraPreview

    var body: some View {
        switch preview {
        case let .session(handle):
            CaptureVideoPreview(session: handle.session)
        case let .still(image):
            Color.black
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        case .blank:
            Color.black
        }
    }
}

private struct CaptureVideoPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CaptureVideoPreviewView {
        CaptureVideoPreviewView(session: session)
    }

    func updateUIView(_ view: CaptureVideoPreviewView, context: Context) {}
}

private final class CaptureVideoPreviewView: UIView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        backgroundColor = .black
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
        if let connection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(90),
           connection.videoRotationAngle != 90 {
            connection.videoRotationAngle = 90
        }
    }
}

#Preview {
    LiveCameraPreviewView(preview: .blank)
}
