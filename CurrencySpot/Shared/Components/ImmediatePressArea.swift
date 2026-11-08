import SwiftUI
import UIKit

// SwiftUI gestures get a lone first touch about 770 ms late in the bottom controls row, and a recognizer attached through SwiftUI only got touches on the icon (iOS 27.2).
struct ImmediatePressArea: UIViewRepresentable {
    let largeContentTitle: String
    let largeContentSymbol: String
    let onChange: (CGPoint) -> Void
    let onEnd: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> RoundTouchView {
        let view = RoundTouchView()
        view.backgroundColor = .clear
        view.showsLargeContentViewer = true
        view.scalesLargeContentImage = true
        view.addInteraction(UILargeContentViewerInteraction())
        let recognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle))
        recognizer.minimumPressDuration = 0
        recognizer.allowableMovement = .greatestFiniteMagnitude
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ view: RoundTouchView, context: Context) {
        context.coordinator.area = self
        view.largeContentTitle = largeContentTitle
        view.largeContentImage = UIImage(systemName: largeContentSymbol)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var area: ImmediatePressArea?

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc func handle(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                area?.onChange(recognizer.location(in: recognizer.view))
            case .ended:
                area?.onEnd()
            case .cancelled, .failed:
                area?.onCancel()
            default:
                break
            }
        }
    }

    final class RoundTouchView: UIView {
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let radius = min(bounds.width, bounds.height) / 2
            return hypot(point.x - bounds.midX, point.y - bounds.midY) <= radius
        }
    }
}
